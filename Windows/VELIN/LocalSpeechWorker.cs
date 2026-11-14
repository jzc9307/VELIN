using System.Buffers.Binary;
using System.Collections.Concurrent;
using System.Diagnostics;
namespace Velin.Windows;

internal sealed class LocalSpeechWorker : IDisposable
{
    readonly Process process;
    readonly Action<string> result, warning;
    readonly List<float> pending = [];
    readonly BlockingCollection<float[]> queue = new(2);
    readonly CancellationTokenSource stop = new();
    readonly object gate = new();
    readonly System.Threading.Timer timer;
    DateTime lastVoice = DateTime.UtcNow;
    bool disposed;
    public static string BundledExecutable()
    {
        using var resource = typeof(LocalSpeechWorker).Assembly.GetManifestResourceStream("VelinSpeech.exe") ?? throw new IOException("The bundled local speech worker is missing. Rebuild with scripts/build-windows.py.");
        using var bytes = new MemoryStream(); resource.CopyTo(bytes); var data = bytes.ToArray(); var hash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(data)).ToLowerInvariant();
        var folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "VELIN", "Workers", hash); Directory.CreateDirectory(folder); var executable = Path.Combine(folder, "VelinSpeech.exe");
        if (!File.Exists(executable) || Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(File.ReadAllBytes(executable))).ToLowerInvariant() != hash) { var temporary = Path.Combine(folder, Guid.NewGuid() + ".tmp"); try { File.WriteAllBytes(temporary, data); File.Move(temporary, executable, true); } finally { if (File.Exists(temporary)) File.Delete(temporary); } }
        return executable;
    }
    public LocalSpeechWorker(string executable, string model, string hint, Action<string> result, Action<string> warning)
    {
        if (!File.Exists(executable) || !File.Exists(model)) throw new IOException("Choose a local multilingual model and a VelinSpeech.exe worker in Audio settings first.");
        this.result = result; this.warning = warning;
        var start = new ProcessStartInfo(executable) { UseShellExecute = false, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true }; start.ArgumentList.Add(model); start.ArgumentList.Add(hint[..Math.Min(1000, hint.Length)]);
        process = Process.Start(start) ?? throw new IOException("The local speech worker could not start."); process.ErrorDataReceived += (_, _) => { }; process.BeginErrorReadLine();
        try { using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(45)); if (Read(timeout.Token).GetAwaiter().GetResult().Length != 0) throw new IOException("Invalid worker startup response."); } catch { process.Kill(true); process.Dispose(); throw new IOException("The local model could not load. Use a multilingual ggml .bin model (not .en) or try Base."); }
        _ = Task.Run(Decode); timer = new System.Threading.Timer(_ => { lock (gate) { if (!disposed && pending.Count >= 8000 && (DateTime.UtcNow - lastVoice).TotalSeconds > .65) Flush(); } }, null, 250, 250);
    }
    public void Feed(byte[] pcm, int count) { lock (gate) { if (disposed) return; double sum = 0; var values = new float[count / 2]; for (int i = 0; i < values.Length; i++) { values[i] = BitConverter.ToInt16(pcm, i * 2) / 32768f; sum += values[i] * values[i]; } var voice = Math.Sqrt(sum / Math.Max(1, values.Length)) > .003125; if (voice) lastVoice = DateTime.UtcNow; if (pending.Count == 0 && !voice) return; pending.AddRange(values); if (pending.Count > 320000) { pending.Clear(); warning("Local speech could not keep up. Choose Base or Windows Speech and restart Listen."); return; } if (pending.Count >= 96000) Flush(); } }
    void Flush() { if (pending.Count == 0) return; if (queue.TryAdd(pending.ToArray())) pending.Clear(); }
    async Task<string> Read(CancellationToken cancellation) { var header = new byte[4]; await process.StandardOutput.BaseStream.ReadExactlyAsync(header, cancellation); var size = BinaryPrimitives.ReadUInt32LittleEndian(header); if (size > 64000) throw new IOException("Invalid worker text size."); var bytes = new byte[size]; await process.StandardOutput.BaseStream.ReadExactlyAsync(bytes, cancellation); return System.Text.Encoding.UTF8.GetString(bytes).Trim(); }
    async Task Decode() { try { foreach (var values in queue.GetConsumingEnumerable(stop.Token)) { var header = new byte[4]; BinaryPrimitives.WriteUInt32LittleEndian(header, (uint)values.Length); var bytes = new byte[values.Length * 4]; Buffer.BlockCopy(values, 0, bytes, 0, bytes.Length); await process.StandardInput.BaseStream.WriteAsync(header, stop.Token); await process.StandardInput.BaseStream.WriteAsync(bytes, stop.Token); await process.StandardInput.BaseStream.FlushAsync(stop.Token); var text = await Read(stop.Token); if (text.Any(char.IsLetterOrDigit) && !stop.IsCancellationRequested) result(text); } } catch (OperationCanceledException) { } catch (Exception) { if (!stop.IsCancellationRequested) warning("Local speech processing stopped. Restart Listen; the transcript is preserved."); } }
    public void Dispose() { lock (gate) { if (disposed) return; disposed = true; } timer.Dispose(); stop.Cancel(); queue.CompleteAdding(); try { if (!process.HasExited) process.Kill(true); } catch { } process.Dispose(); }
}
