using System.Diagnostics;
using System.Text.Json;
using Velin.Core;
namespace Velin.Windows;
internal static class UpdateInstaller
{
    public static int Apply(string planPath)
    {
        string? safeTarget=null;
        try{
            var plan=JsonSerializer.Deserialize<UpdateInstallPlan>(File.ReadAllText(planPath))??throw new IOException("Invalid update plan.");var target=Path.GetFullPath(plan.Target);var workspace=Path.GetFullPath(plan.Workspace);var archive=Path.GetFullPath(plan.Archive);
            if(Path.GetDirectoryName(Path.GetFullPath(planPath))!=workspace||Path.GetDirectoryName(archive)!=workspace||!target.EndsWith(".exe",StringComparison.OrdinalIgnoreCase)||File.GetAttributes(target).HasFlag(FileAttributes.ReparsePoint))throw new IOException("Unexpected update location.");
            var manifest=UpdateManifest.Verify(plan.Envelope,AppUpdates.PublicKey);if(UpdateManifest.Compare(manifest.Version,manifest.Build,plan.CurrentVersion,plan.CurrentBuild)<=0)throw new IOException("An older update cannot replace this app.");manifest.VerifyFile(archive,manifest.Windows);
            var old=FileVersionInfo.GetVersionInfo(target);if(old.ProductName!="VELIN"&&old.InternalName!="VELIN.dll")throw new IOException("The target is not VELIN.");if($"{old.FileMajorPart}.{old.FileMinorPart}.{old.FileBuildPart}"!=plan.CurrentVersion||old.FilePrivatePart!=plan.CurrentBuild)throw new IOException("The installed app changed. Check for updates again.");
            var version=FileVersionInfo.GetVersionInfo(archive);if($"{version.FileMajorPart}.{version.FileMinorPart}.{version.FileBuildPart}"!=manifest.Version||version.FilePrivatePart!=manifest.Build)throw new IOException("Downloaded version differs from its signed release.");safeTarget=target;
            var suffix=Guid.NewGuid().ToString();var prepared=target+"."+suffix+".new";var backup=target+"."+suffix+".previous";File.Copy(archive,prepared);manifest.VerifyFile(prepared,manifest.Windows);
            try{using var parent=Process.GetProcessById(plan.ParentPID);if(!string.Equals(parent.MainModule?.FileName,target,StringComparison.OrdinalIgnoreCase))throw new IOException("Update belongs to another process.");if(!parent.WaitForExit(60000))throw new IOException("VELIN stayed open. Your app was preserved.");}catch(ArgumentException){}
            File.Replace(prepared,target,backup);
            try{manifest.VerifyFile(target,manifest.Windows);Process.Start(new ProcessStartInfo(target){UseShellExecute=true});}catch{File.Replace(backup,target,target+".failed");throw;}
            File.WriteAllText(Path.Combine(workspace,"result.txt"),"Updated to "+manifest.Version+". Previous executable retained at "+backup);return 0;
        }catch(Exception e){MessageBox.Show("The update was not installed: "+e.Message+"\nYour previous app and local data were preserved.","VELIN Update",MessageBoxButtons.OK,MessageBoxIcon.Information);if(safeTarget!=null)try{Process.Start(new ProcessStartInfo(safeTarget){UseShellExecute=true});}catch{}return 1;}
    }
}
