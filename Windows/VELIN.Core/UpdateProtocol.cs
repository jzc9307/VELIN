using System.Security.Cryptography;
using System.Text.Json;
namespace Velin.Core;

public sealed record UpdateArtifact(string Name,string Url,string Sha256,long Size);
public sealed record UpdateManifest(int Schema,string Repository,string Version,int Build,string Notes,UpdateArtifact Mac,UpdateArtifact Windows)
{
    static readonly JsonSerializerOptions Json=new(){PropertyNameCaseInsensitive=true};
    public static int Compare(string version,int build,string current,int currentBuild)
    {
        static Version Parse(string text){var p=text.Split('.');if(p.Length!=3||p.Any(x=>x.Length==0||x.Length>6||x.Any(c=>c<'0'||c>'9')))throw new IOException("Invalid update version.");return System.Version.Parse(text);}
        if(build<=0||currentBuild<=0)throw new IOException("Invalid update build.");var c=Parse(version).CompareTo(Parse(current));return c==0?build.CompareTo(currentBuild):c;
    }
    public void Validate()
    {
        if(Schema!=1||Repository!="jzc9307/VELIN"||Notes.Length>5000)throw new IOException("This update does not belong to VELIN.");Compare(Version,Build,Version,Build);
        foreach(var (file,suffix,max) in new[]{(Mac,"macOS-arm64.zip",500_000_000L),(Windows,"Windows-x64.exe",800_000_000L)}){
            var name=$"VELIN-{Version}-{suffix}";
            if(file.Name!=name||file.Url!=$"https://github.com/jzc9307/VELIN/releases/download/v{Version}/{name}"||file.Size<=0||file.Size>max||file.Sha256.Length!=64||file.Sha256.Any(c=>!"0123456789abcdef".Contains(c)))throw new IOException("Invalid signed update destination or file size.");
        }
    }
    public static UpdateManifest Verify(byte[] envelope,string publicKey)
    {
        if(envelope.Length>65536)throw new IOException("Oversized update signature.");
        using var doc=JsonDocument.Parse(envelope);var payload=Convert.FromBase64String(doc.RootElement.GetProperty("payload").GetString()!);var signature=Convert.FromBase64String(doc.RootElement.GetProperty("signature").GetString()!);var raw=Convert.FromBase64String(publicKey);
        if(raw.Length!=65||raw[0]!=4||signature.Length!=64)throw new IOException("Invalid update key or signature.");
        using var key=ECDsa.Create(new ECParameters{Curve=ECCurve.NamedCurves.nistP256,Q=new ECPoint{X=raw[1..33],Y=raw[33..65]}});
        if(!key.VerifyData(payload,signature,HashAlgorithmName.SHA256,DSASignatureFormat.IeeeP1363FixedFieldConcatenation))throw new IOException("Update signature verification failed. Your app was preserved.");
        var manifest=JsonSerializer.Deserialize<UpdateManifest>(payload,Json)??throw new IOException("Invalid signed update.");manifest.Validate();return manifest;
    }
    public void VerifyFile(string path,UpdateArtifact artifact)
    {
        using var file=File.OpenRead(path);if(file.Length!=artifact.Size||!Convert.ToHexString(SHA256.HashData(file)).Equals(artifact.Sha256,StringComparison.OrdinalIgnoreCase))throw new IOException("The update download changed or is incomplete. Your app was preserved.");
    }
}
public static class UpdateNetworkPolicy
{
    public static bool Allowed(Uri uri)=>uri.Scheme=="https"&&string.IsNullOrEmpty(uri.UserInfo)&&uri.IsDefaultPort&&new[]{"api.github.com","github.com","release-assets.githubusercontent.com","objects.githubusercontent.com","github-releases.githubusercontent.com"}.Contains(uri.Host.ToLowerInvariant());
}
