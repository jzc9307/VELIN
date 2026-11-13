using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
namespace Velin.Windows;

internal static class CredentialStore
{
    const uint Generic = 1, LocalMachine = 2;
    static string Target(Guid id) => "VELIN/providers/" + id;
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct Credential { public uint Flags, Type; public string TargetName; public string? Comment; public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten; public uint CredentialBlobSize; public IntPtr CredentialBlob; public uint Persist, AttributeCount; public IntPtr Attributes; public string? TargetAlias; public string UserName; }
    [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool ReadNative(string target, uint type, uint flags, out IntPtr credential);
    [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool WriteNative(ref Credential credential, uint flags);
    [DllImport("advapi32.dll", EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool DeleteNative(string target, uint type, uint flags);
    [DllImport("advapi32.dll")] static extern void CredFree(IntPtr pointer);
    public static string Read(Guid id)
    {
        if (!ReadNative(Target(id), Generic, 0, out var pointer)) { var error = Marshal.GetLastWin32Error(); if (error == 1168) return ""; throw new Win32Exception(error, "Windows could not open this saved VELIN credential."); }
        try { var item = Marshal.PtrToStructure<Credential>(pointer); return Marshal.PtrToStringUni(item.CredentialBlob, checked((int)item.CredentialBlobSize / 2)) ?? ""; }
        finally { CredFree(pointer); }
    }
    public static bool Exists(Guid id)
    {
        if (!ReadNative(Target(id), Generic, 0, out var pointer)) return false;
        CredFree(pointer); return true;
    }
    public static void Save(Guid id, string value)
    {
        if (value.Length == 0) { if (!DeleteNative(Target(id), Generic, 0) && Marshal.GetLastWin32Error() != 1168) throw new Win32Exception(Marshal.GetLastWin32Error()); return; }
        var bytes = Encoding.Unicode.GetBytes(value); if (bytes.Length > 5120) throw new ArgumentException("API key is too long.");
        var blob = Marshal.AllocHGlobal(bytes.Length);
        try { Marshal.Copy(bytes, 0, blob, bytes.Length); var item = new Credential { Type = Generic, TargetName = Target(id), CredentialBlobSize = (uint)bytes.Length, CredentialBlob = blob, Persist = LocalMachine, UserName = "VELIN" }; if (!WriteNative(ref item, 0)) throw new Win32Exception(Marshal.GetLastWin32Error(), "Windows could not save this credential."); }
        finally { for (var i = 0; i < bytes.Length; i++) Marshal.WriteByte(blob, i, 0); Marshal.FreeHGlobal(blob); Array.Clear(bytes); }
    }
}
