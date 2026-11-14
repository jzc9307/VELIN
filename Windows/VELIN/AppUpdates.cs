using System.Diagnostics;
using System.Text.Json;
using System.Security.Cryptography;
using Velin.Core;
namespace Velin.Windows;

internal sealed class AppUpdates:IDisposable
{
    public event Action? Changed;
    public UpdateManifest? Available {get;private set;}
    public bool Launching {get;private set;}=true;
    public bool Checking {get;private set;}
    public bool Downloading {get;private set;}
    public bool PresentingDownload {get;private set;}
    public bool Ready {get;private set;}
    public double Progress {get;private set;}
    public string Status {get;private set;}="Checking GitHub Releases…";
    public string? Failure {get;private set;}
    public string? LatestPublishedVersion {get;private set;}
    public int? LatestPublishedBuild {get;private set;}
    public DateTime? LastChecked {get;private set;}
    public Func<bool> CanRestart {get;set;}=()=>true;
    public Action Restart {get;set;}=()=>{};
    public Action PrepareRestart {get;set;}=()=>{};
    bool installing;byte[]? envelope;string? workspace,archive;CancellationTokenSource? download;
    readonly HttpClient http=new(new HttpClientHandler{AllowAutoRedirect=false,UseCookies=false}){Timeout=TimeSpan.FromMinutes(15)};
    public static string PublicKey {get{using var stream=typeof(AppUpdates).Assembly.GetManifestResourceStream("UpdatePublicKey")!;using var reader=new StreamReader(stream);return reader.ReadToEnd().Trim();}}
    public static string Version=>FileVersionInfo.GetVersionInfo(Environment.ProcessPath!).FileVersion is string value?string.Join('.',value.Split('.').Take(3)):"0.0.0";
    public static int Build=>FileVersionInfo.GetVersionInfo(Environment.ProcessPath!).FilePrivatePart;
    public string VersionStatus {
        get {
            if(Checking)return "Checking for a newer release…";
            if(LatestPublishedVersion==null)return Failure==null?"Not checked yet":"Couldn’t confirm the latest version";
            try {var difference=UpdateManifest.Compare(Version,Build,LatestPublishedVersion,LatestPublishedBuild??Build);return difference>0?"This build is newer than the latest public release":difference<0?"A newer public release is available":LatestPublishedBuild==null?"You have the latest published version · build unavailable":"You’re on the latest version";}catch{return "Couldn’t compare release versions";}
        }
    }
    public static string CurrentReleaseNotes {
        get {try {using var stream=typeof(AppUpdates).Assembly.GetManifestResourceStream("ReleaseNotes");if(stream==null)return "Release notes aren’t bundled with this build.";using var doc=JsonDocument.Parse(stream);if(doc.RootElement.GetProperty("version").GetString()!=Version||doc.RootElement.GetProperty("build").GetInt32()!=Build)return "Release notes do not match this build.";return doc.RootElement.GetProperty("notes").GetString()??"No release notes provided.";}catch{return "Release notes aren’t available for this build.";}}
    }
    void Notify()=>Changed?.Invoke();
    public void SkipLaunch(){Launching=false;Notify();}
    async Task<HttpResponseMessage> Get(Uri uri,CancellationToken token)
    {
        for(int i=0;i<5;i++){
            if(!UpdateNetworkPolicy.Allowed(uri))throw new IOException("Unexpected update destination.");
            using var request=new HttpRequestMessage(HttpMethod.Get,uri);request.Headers.UserAgent.ParseAdd("VELIN-Update-Check");var response=await http.SendAsync(request,HttpCompletionOption.ResponseHeadersRead,token);
            if((int)response.StatusCode>=300&&(int)response.StatusCode<400){var next=response.Headers.Location;response.Dispose();if(next==null)throw new IOException("Update download redirected without a destination.");uri=next.IsAbsoluteUri?next:new Uri(uri,next);continue;}
            if(!response.IsSuccessStatusCode){response.Dispose();throw new IOException("GitHub could not provide this update.");}return response;
        }throw new IOException("Too many update redirects.");
    }
    async Task<byte[]> Small(Uri uri,CancellationToken token)
    {
        using var response=await Get(uri,token);await using var input=await response.Content.ReadAsStreamAsync(token);using var output=new MemoryStream();var buffer=new byte[8192];
        while(true){var count=await input.ReadAsync(buffer,token);if(count==0)break;if(output.Length+count>262144)throw new IOException("Oversized release metadata.");output.Write(buffer,0,count);}return output.ToArray();
    }
    public async Task Check()
    {
        if(Checking||Downloading||Ready)return;Checking=true;Failure=null;Available=null;envelope=null;LatestPublishedVersion=null;LatestPublishedBuild=null;Status="Checking GitHub Releases…";Notify();var started=DateTime.UtcNow;
        using var timeout=new CancellationTokenSource(TimeSpan.FromSeconds(8));
        try{
            using var doc=JsonDocument.Parse(await Small(new Uri("https://api.github.com/repos/jzc9307/VELIN/releases/latest"),timeout.Token));var release=doc.RootElement;
            if(release.GetProperty("draft").GetBoolean()||release.GetProperty("prerelease").GetBoolean())throw new IOException("No stable release is available.");var tag=release.GetProperty("tag_name").GetString()!;if(!tag.StartsWith('v'))throw new IOException("Invalid release tag.");var version=tag[1..];LatestPublishedVersion=version;
            if(UpdateManifest.Compare(version,int.MaxValue,Version,Build)<=0){Available=null;Status="You’re up to date";return;}
            var url=$"https://github.com/jzc9307/VELIN/releases/download/{tag}/VELIN-update.json";
            if(!release.GetProperty("assets").EnumerateArray().Any(a=>a.GetProperty("name").GetString()=="VELIN-update.json"&&a.GetProperty("browser_download_url").GetString()==url)){
                if(UpdateManifest.Compare(version,1,Version,Build)>0)throw new IOException("This release has no signed in-app update. Use its GitHub download instead.");Status="You’re up to date";return;
            }
            var signed=await Small(new Uri(url),timeout.Token);var manifest=UpdateManifest.Verify(signed,PublicKey);if(manifest.Version!=version||!release.GetProperty("assets").EnumerateArray().Any(a=>a.GetProperty("name").GetString()==manifest.Windows.Name&&a.GetProperty("browser_download_url").GetString()==manifest.Windows.Url))throw new IOException("Release and signed update versions differ.");
            LatestPublishedBuild=manifest.Build;
            if(UpdateManifest.Compare(manifest.Version,manifest.Build,Version,Build)>0){Available=manifest;envelope=signed;Status="A little more clarity is ready.";}else{Available=null;Status="You’re up to date";}
        }catch{Status="Couldn’t check for updates";Failure="GitHub is unavailable or this release could not be authenticated. Try again later.";}
        finally{var remaining=TimeSpan.FromMilliseconds(550)-(DateTime.UtcNow-started);if(remaining>TimeSpan.Zero)await Task.Delay(remaining);Checking=false;Launching=false;LastChecked=DateTime.Now;Notify();}
    }
    public async Task DownloadAndRestart()
    {
        if(installing||Downloading||Available==null||envelope==null)return;if(!CanRestart()){Failure="Stop Listen/Mic, finish the answer, and send or clear your draft before restarting.";Notify();return;}if(Ready){Install();return;}
        var manifest=Available;Downloading=true;PresentingDownload=true;Progress=0;Failure=null;Status="Downloading VELIN "+manifest.Version+"…";Notify();using var cancel=new CancellationTokenSource(TimeSpan.FromMinutes(15));download=cancel;
        try{
            workspace=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"VELIN","Updates",Guid.NewGuid()+".noindex");Directory.CreateDirectory(workspace);archive=Path.Combine(workspace,manifest.Windows.Name);
            using var response=await Get(new Uri(manifest.Windows.Url),cancel.Token);await using(var input=await response.Content.ReadAsStreamAsync(cancel.Token))await using(var output=File.Create(archive)){
                var buffer=new byte[65536];long total=0;var last=DateTime.MinValue;while(true){var count=await input.ReadAsync(buffer,cancel.Token);if(count==0)break;total+=count;if(total>manifest.Windows.Size)throw new IOException("Update download exceeded its signed size.");await output.WriteAsync(buffer.AsMemory(0,count),cancel.Token);Progress=(double)total/manifest.Windows.Size;if((DateTime.UtcNow-last).TotalMilliseconds>100){last=DateTime.UtcNow;Notify();}}
            }
            Status="Verifying your signed update…";Notify();await Task.Run(()=>manifest.VerifyFile(archive,manifest.Windows));cancel.Token.ThrowIfCancellationRequested();Ready=true;
            if(CanRestart())Install();else{Status="Ready when you are";Failure="Stop Listen and Mic and finish the answer, then install and restart.";}
        }catch(OperationCanceledException){Failure="Download cancelled. Your existing app was preserved.";Status="Ready to use";}catch(Exception e){Failure=e.Message;Status="Couldn’t install this update";}finally{Downloading=false;download=null;Notify();}
    }
    void Install()
    {
        if(installing||!CanRestart()||workspace==null||archive==null||envelope==null)return;
        try{
            var target=Environment.ProcessPath!;var folder=Path.GetDirectoryName(target)!;var probe=Path.Combine(folder,".velin-write-check-"+Guid.NewGuid());File.WriteAllText(probe,"");File.Delete(probe);
            var helper=Path.Combine(workspace,"VELINUpdater.exe");if(!File.Exists(helper))File.Copy(target,helper);else if(!SHA256.HashData(File.ReadAllBytes(helper)).SequenceEqual(SHA256.HashData(File.ReadAllBytes(target))))throw new IOException("The staged updater changed. Download again.");var plan=new UpdateInstallPlan(target,Environment.ProcessId,Version,Build,envelope,archive,workspace);var planPath=Path.Combine(workspace,"plan.json");File.WriteAllText(planPath,JsonSerializer.Serialize(plan));
            var start=new ProcessStartInfo(helper){UseShellExecute=false};start.ArgumentList.Add("--apply-update");start.ArgumentList.Add(planPath);PrepareRestart();Process.Start(start);installing=true;Status="Restarting into your new version…";Restart();
        }catch(Exception e){Failure=e.Message;Status="Move VELIN to a writable folder before updating.";Notify();}
    }
    public void Cancel(){download?.Cancel();PresentingDownload=false;Notify();}
    public void Dismiss(){PresentingDownload=false;Notify();}
    public void Dispose(){download?.Cancel();http.Dispose();}
}
internal sealed record UpdateInstallPlan(string Target,int ParentPID,string CurrentVersion,int CurrentBuild,byte[] Envelope,string Archive,string Workspace);
