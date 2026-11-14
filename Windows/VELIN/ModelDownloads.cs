using System.Security.Cryptography;
namespace Velin.Windows;

internal sealed record SpeechModel(string Id, string Name, string Size, string Sha, string Detail)
{
    public string FileName => "ggml-"+Id+".bin";
    public string PathOnDisk => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "VELIN", "Models", FileName);
}
internal static class ModelDownloads
{
    public static readonly SpeechModel[] Models = [
        new("base","Base","142 MB","465707469ff3a37a2b9b8d8f89f2f99de7299dac","Lightweight; limited mixed-language accuracy"),
        new("small","Small","466 MB","55356645c2b361a969dfd0ef2c5a50d530afd8d5","More capacity than Base"),
        new("large-v3-turbo-q5_0","Turbo","547 MB","e050f7970618a659205450ad97eb95a18d69c9ee","Larger multilingual model; more memory")
    ];
    public static async Task<bool> Installed(SpeechModel model, CancellationToken cancellation = default)
    {
        if (!File.Exists(model.PathOnDisk)) return false;
        await using var file = File.OpenRead(model.PathOnDisk);
        return Convert.ToHexString(await SHA1.HashDataAsync(file,cancellation)).Equals(model.Sha,StringComparison.OrdinalIgnoreCase);
    }
    public static async Task<string> Fetch(SpeechModel model, IProgress<double> progress, CancellationToken cancellation)
    {
        if (await Installed(model,cancellation)) return model.PathOnDisk;
        var folder=Path.GetDirectoryName(model.PathOnDisk)!;Directory.CreateDirectory(folder);var temporary=Path.Combine(folder,Guid.NewGuid()+".partial");
        try {
            using var client=new HttpClient{Timeout=TimeSpan.FromMinutes(15)};
            using var response=await client.GetAsync("https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"+model.FileName,HttpCompletionOption.ResponseHeadersRead,cancellation);response.EnsureSuccessStatusCode();
            await using(var input=await response.Content.ReadAsStreamAsync(cancellation)) await using(var output=File.Create(temporary)) {
                var buffer=new byte[1024*1024];long received=0;
                while(true){var count=await input.ReadAsync(buffer,cancellation);if(count==0)break;await output.WriteAsync(buffer.AsMemory(0,count),cancellation);received+=count;progress.Report((double)received/(response.Content.Headers.ContentLength??574000000));}
            }
            await using(var file=File.OpenRead(temporary)){if(!Convert.ToHexString(await SHA1.HashDataAsync(file,cancellation)).Equals(model.Sha,StringComparison.OrdinalIgnoreCase))throw new IOException("Model integrity check failed. The download was not installed.");}
            File.Move(temporary,model.PathOnDisk,true);return model.PathOnDisk;
        } finally { if(File.Exists(temporary))File.Delete(temporary); }
    }
}
