using System.Collections.Concurrent;
using System.Globalization;
using System.Speech.AudioFormat;
using System.Speech.Recognition;
using NAudio.Wave;
namespace Velin.Windows;

internal sealed class AudioCapture : IDisposable
{
    readonly List<Channel> channels = [];
    public event Action<string, string, bool>? Text;
    public event Action<string>? Warning;
    public event Action<string, float>? Level;
    public bool IsRunning => channels.Count > 0;
    public void Start(bool microphone, bool computer, string language)
    {
        Stop(); if (!microphone && !computer) throw new InvalidOperationException("Enable microphone or computer audio in Audio settings.");
        var engine = SpeechRecognitionEngine.InstalledRecognizers().FirstOrDefault(r => r.Culture.Name.Equals(language, StringComparison.OrdinalIgnoreCase));
        if (engine == null) throw new InvalidOperationException("Install the Windows speech language " + language + " in Settings → Time & language → Speech, then restart VELIN. This preview uses installed local speech engines.");
        foreach (var source in new[] { "You", "Computer" })
        {
            if (source == "You" && !microphone || source == "Computer" && !computer) continue;
            try { var channel = new Channel(source, engine.Id, (s, t, final) => Text?.Invoke(s, t, final), w => Warning?.Invoke(w), (s, v) => Level?.Invoke(s, v)); channel.Start(); channels.Add(channel); }
            catch (Exception e) { Warning?.Invoke(source + ": " + e.Message); }
        }
        if (channels.Count == 0) throw new InvalidOperationException("Neither audio source started. Check audio devices, speech language, and Windows microphone privacy settings.");
    }
    public void Stop() { foreach (var channel in channels) channel.Dispose(); channels.Clear(); }
    public void Dispose() => Stop();
    sealed class Channel : IDisposable
    {
        readonly string source;
        readonly IWaveIn capture = null!;
        readonly SpeechRecognitionEngine recognizer = null!;
        readonly PcmStream speech = new();
        readonly BufferedWaveProvider input;
        readonly MediaFoundationResampler converter = null!;
        readonly Action<string> warning;
        readonly Action<string, float> meter;
        readonly object gate = new();
        bool disposed;
        public Channel(string source, string recognizerId, Action<string, string, bool> output, Action<string> warning, Action<string, float> meter)
        {
            this.source = source; this.warning = warning; this.meter = meter;
            try
            {
                capture = source == "Computer" ? new WasapiLoopbackCapture() : new WaveInEvent { WaveFormat = new WaveFormat(16000, 16, 1), BufferMilliseconds = 100 };
                input = new BufferedWaveProvider(capture.WaveFormat) { ReadFully = false, BufferDuration = TimeSpan.FromSeconds(4), DiscardOnBufferOverflow = false };
                converter = new MediaFoundationResampler(input, new WaveFormat(16000, 16, 1)) { ResamplerQuality = 60 };
                recognizer = new SpeechRecognitionEngine(recognizerId);
                recognizer.LoadGrammar(new DictationGrammar());
                recognizer.SpeechHypothesized += (_, e) => { if (!disposed) output(source, e.Result.Text, false); };
                recognizer.SpeechRecognized += (_, e) => { if (!disposed && !string.IsNullOrWhiteSpace(e.Result.Text)) output(source, e.Result.Text, true); };
                recognizer.RecognizeCompleted += (_, e) => { if (!disposed && e.Error != null) warning(source + " recognition stopped: " + e.Error.Message); };
                recognizer.SetInputToAudioStream(speech, new SpeechAudioFormatInfo(16000, AudioBitsPerSample.Sixteen, AudioChannel.Mono));
                capture.DataAvailable += OnData;
                capture.RecordingStopped += (_, e) => { if (!disposed && e.Exception != null) warning(source + " audio stopped: " + e.Exception.Message); };
            }
            catch { Dispose(); throw; }
        }
        public void Start() { try { recognizer.RecognizeAsync(RecognizeMode.Multiple); capture.StartRecording(); } catch { Dispose(); throw; } }
        void OnData(object? sender, WaveInEventArgs e)
        {
            lock (gate)
            {
                if (disposed) return;
                try
                {
                    input.AddSamples(e.Buffer, 0, e.BytesRecorded);
                    var buffer = new byte[6400];
                    while (input.BufferedBytes > capture.WaveFormat.BlockAlign)
                    {
                        var count = converter.Read(buffer, 0, buffer.Length); if (count <= 0) break;
                        double sum = 0; for (var i = 0; i + 1 < count; i += 2) { var v = BitConverter.ToInt16(buffer, i) / 32768.0; sum += v * v; }
                        meter(source, (float)Math.Min(1, Math.Sqrt(sum / Math.Max(1, count / 2)) * 8));
                        if (!speech.Feed(buffer.AsSpan(0, count).ToArray())) throw new IOException("Speech processing could not keep up; stop and restart Listen.");
                    }
                }
                catch (Exception error) { warning(source + ": " + error.Message); }
            }
        }
        public void Dispose()
        {
            lock (gate) { if (disposed) return; disposed = true; }
            try { capture.StopRecording(); } catch { }
            speech.Complete();
            try { recognizer.RecognizeAsyncCancel(); } catch { }
            recognizer?.Dispose(); capture?.Dispose(); converter?.Dispose(); speech.Dispose();
        }
    }
    sealed class PcmStream : Stream
    {
        readonly BlockingCollection<byte[]> queue = new(100); byte[] current = []; int offset; bool closed;
        public bool Feed(byte[] data) => !closed && queue.TryAdd(data);
        public void Complete() { closed = true; queue.CompleteAdding(); }
        public override int Read(byte[] buffer, int start, int count)
        {
            if (count == 0) return 0;
            while (offset >= current.Length) { try { current = queue.Take(); offset = 0; } catch (InvalidOperationException) { return 0; } }
            var length = Math.Min(count, current.Length - offset); Array.Copy(current, offset, buffer, start, length); offset += length; return length;
        }
        protected override void Dispose(bool disposing) { if (disposing) Complete(); base.Dispose(disposing); }
        public override bool CanRead => true; public override bool CanSeek => false; public override bool CanWrite => false;
        public override long Length => throw new NotSupportedException(); public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
        public override void Flush() { }
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException(); public override void SetLength(long value) => throw new NotSupportedException(); public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
    }
}
