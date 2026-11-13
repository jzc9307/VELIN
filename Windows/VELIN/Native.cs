using System.Runtime.InteropServices;
namespace Velin.Windows;

internal static class Native
{
    [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr window, int id, uint modifiers, uint key);
    [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr window, int id);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool SetWindowDisplayAffinity(IntPtr window, uint affinity);
    [DllImport("user32.dll")] static extern bool ReleaseCapture();
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr window, uint message, IntPtr wparam, IntPtr lparam);
    [DllImport("user32.dll", EntryPoint = "SendMessageW")] static extern IntPtr Message(IntPtr window, uint message, IntPtr wparam, IntPtr lparam);
    public static int FirstVisibleLine(IntPtr window) => (int)Message(window, 0xCE, IntPtr.Zero, IntPtr.Zero);
    public static void ScrollLines(IntPtr window, int lines) => Message(window, 0xB6, IntPtr.Zero, (IntPtr)lines);
    public static void Drag(Form form) { ReleaseCapture(); SendMessage(form.Handle, 0xA1, 2, IntPtr.Zero); }
}
