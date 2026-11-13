namespace Velin.Windows;

internal static class Program
{
    [STAThread] static void Main() { ApplicationConfiguration.Initialize(); using var single = new Mutex(true, "Local\\VELIN.Assistant", out var first); if (!first) { MessageBox.Show("VELIN is already running. Use its tray icon or Ctrl+Alt+Space."); return; } try { using var state = new Controller(); using var main = new MainForm(state); using var overlay = new OverlayForm(state); state.Main = main; state.Overlay = overlay; Application.Run(main); } catch (Exception e) { MessageBox.Show(e.Message, "VELIN could not start", MessageBoxButtons.OK, MessageBoxIcon.Error); } }
}
