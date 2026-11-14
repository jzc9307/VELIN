using System.Text.Json;
namespace Velin.Core;
public static class SonioxProtocol
{
    public static readonly Guid CredentialId=new("A883C4F8-5FC1-4841-9918-997F039BF56B");
    public const string Endpoint="wss://stt-rt.soniox.com/transcribe-websocket";
    public static string Configuration=>JsonSerializer.Serialize(new{model="stt-rt-v6",audio_format="pcm_s16le",sample_rate=16000,num_channels=1,language_hints=new[]{"en","ms","zh"},language_hints_strict=false,enable_endpoint_detection=true,max_endpoint_delay_ms=1000});
}
public sealed class SonioxTranscript
{
    string confirmed="";
    public string Preview {get;private set;}="";
    public List<string> Accept(JsonElement response)
    {
        if(response.TryGetProperty("error_code",out var code))throw new IOException("Soniox could not transcribe (HTTP "+code.GetInt32()+"). Check the speech key, credits and service availability.");
        var completed=new List<string>();var tentative="";
        if(response.TryGetProperty("tokens",out var tokens))foreach(var token in tokens.EnumerateArray()){
            var text=token.GetProperty("text").GetString()??"";var final=token.TryGetProperty("is_final",out var f)&&f.GetBoolean();
            if(text is "<end>" or "<fin>"){if(final){if(!string.IsNullOrWhiteSpace(confirmed))completed.Add(confirmed);confirmed="";}}
            else if(!text.StartsWith('<')){if(final)confirmed+=text;else tentative+=text;}
        }
        if(response.TryGetProperty("finished",out var done)&&done.GetBoolean()){if(confirmed.Length>0)completed.Add(confirmed);confirmed="";tentative="";}
        if(confirmed.Length+tentative.Length>12000)throw new IOException("Soniox returned an unusually long unfinished segment. Restart this audio control.");
        Preview=confirmed+tentative;return completed;
    }
}
