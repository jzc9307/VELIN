using System.Security.Cryptography;
namespace Velin.Windows;

internal static class ModelDownloads
{
    public static async Task<string> Fetch(bool small, IProgress<double> progress, CancellationToken cancellation)
    {
        var name = small ? "small" : "base"; var expected = small ? "55356645c2b361a969dfd0ef2c5a50d530afd8d5" : "465707469ff3a37a2b9b8d8f89f2f99de7299dac";
        var folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "VELIN", "Models"); Directory.CreateDirectory(folder); var temporary = Path.Combine(folder, Guid.NewGuid() + ".partial");
        try { using var client = new HttpClient { Timeout = TimeSpan.FromMinutes(15) }; using var response = await client.GetAsync("https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-" + name + ".bin", HttpCompletionOption.ResponseHeadersRead, cancellation); response.EnsureSuccessStatusCode(); await using (var input = await response.Content.ReadAsStreamAsync(cancellation)) await using (var output = File.Create(temporary)) { var buffer = new byte[1024 * 1024]; long received = 0; while (true) { var count = await input.ReadAsync(buffer, cancellation); if (count == 0) break; await output.WriteAsync(buffer.AsMemory(0, count), cancellation); received += count; progress.Report((double)received / (response.Content.Headers.ContentLength ?? (small ? 488000000 : 148000000))); } } await using (var verify = File.OpenRead(temporary)) { var hash = Convert.ToHexString(await SHA1.HashDataAsync(verify, cancellation)).ToLowerInvariant(); if (hash != expected) throw new IOException("Model integrity check failed. The download was not installed."); } var destination = Path.Combine(folder, "ggml-" + name + ".bin"); File.Move(temporary, destination, true); return destination; }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
}
