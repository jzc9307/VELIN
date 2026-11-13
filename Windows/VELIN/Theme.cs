using System.Drawing.Drawing2D;
namespace Velin.Windows;

internal static class Theme
{
    public static readonly Color Background = Color.FromArgb(12, 16, 20), Surface = Color.FromArgb(23, 30, 37), Sidebar = Color.FromArgb(16, 22, 27), Mint = Color.FromArgb(162, 236, 213), Lilac = Color.FromArgb(184, 164, 255), Muted = Color.FromArgb(147, 160, 174), Line = Color.FromArgb(47, 57, 65);
    public static Font Font(float size = 10, FontStyle style = FontStyle.Regular) => new("Segoe UI", size, style);
    public static TextBox Input(string text = "", bool multiline = false) => new() { Text = text, Multiline = multiline, BackColor = Background, ForeColor = Color.White, BorderStyle = BorderStyle.FixedSingle, Font = Font(), Height = multiline ? 80 : 30, Dock = DockStyle.Top, Margin = new Padding(0, 4, 0, 14) };
    public static Label Label(string text, float size = 10, Color? color = null) => new() { Text = text, Font = Font(size), ForeColor = color ?? Color.White, AutoSize = true, Margin = new Padding(0, 8, 0, 8) };
    public static FlowLayoutPanel Row() => new() { AutoSize = true, FlowDirection = FlowDirection.LeftToRight, WrapContents = true, Dock = DockStyle.Top, BackColor = Color.Transparent, Padding = new Padding(0, 4, 0, 4) };
    public static FlowLayoutPanel Column() => new() { AutoScroll = true, FlowDirection = FlowDirection.TopDown, WrapContents = false, Dock = DockStyle.Fill, Padding = new Padding(24), BackColor = Background };
    public static GraphicsPath Rounded(RectangleF bounds, float radius = 12) { var p = new GraphicsPath(); var d = radius * 2; p.AddArc(bounds.X, bounds.Y, d, d, 180, 90); p.AddArc(bounds.Right - d, bounds.Y, d, d, 270, 90); p.AddArc(bounds.Right - d, bounds.Bottom - d, d, d, 0, 90); p.AddArc(bounds.X, bounds.Bottom - d, d, d, 90, 90); p.CloseFigure(); return p; }
}
internal sealed class ClickButton : Button
{
    bool hover, pressed;
    [System.ComponentModel.DesignerSerializationVisibility(System.ComponentModel.DesignerSerializationVisibility.Hidden)]
    public bool Primary { get; set; }
    public ClickButton(string text, Action click, bool primary = false) { Text = text; Primary = primary; AutoSize = false; Height = 34; Width = Math.Max(36, TextRenderer.MeasureText(text, Theme.Font()).Width + 24); Font = Theme.Font(10, FontStyle.Bold); ForeColor = Color.White; FlatStyle = FlatStyle.Flat; FlatAppearance.BorderSize = 0; Cursor = Cursors.Hand; Margin = new Padding(4); Click += (_, _) => click(); SetStyle(ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer, true); }
    protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hover = pressed = false; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnMouseDown(MouseEventArgs e) { pressed = true; Invalidate(); base.OnMouseDown(e); }
    protected override void OnMouseUp(MouseEventArgs e) { pressed = false; Invalidate(); base.OnMouseUp(e); }
    protected override void OnPaint(PaintEventArgs e) { e.Graphics.SmoothingMode = SmoothingMode.AntiAlias; var r = new RectangleF(1, 1, Width - 3, Height - 3); if (pressed) r.Inflate(-1, -1); using var path = Theme.Rounded(r, 10); using var fill = new SolidBrush(Primary ? Theme.Mint : pressed ? Color.FromArgb(62, 77, 82) : hover ? Color.FromArgb(43, 55, 61) : Theme.Surface); e.Graphics.FillPath(fill, path); using var pen = new Pen(hover || pressed ? Theme.Mint : Theme.Line); e.Graphics.DrawPath(pen, path); TextRenderer.DrawText(e.Graphics, Text, Font, Rectangle.Round(r), Enabled ? (Primary ? Theme.Background : Color.White) : Theme.Muted, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter); }
}

internal sealed class WrappedLabel : Label
{
    public WrappedLabel() { AutoSize = false; Height = 60; }
    protected override void OnSizeChanged(EventArgs e) { base.OnSizeChanged(e); Fit(); }
    protected override void OnTextChanged(EventArgs e) { base.OnTextChanged(e); Fit(); }
    void Fit() { if (Width < 20) return; var size = TextRenderer.MeasureText(Text, Font, new Size(Width, 10000), TextFormatFlags.WordBreak | TextFormatFlags.TextBoxControl); var height = Math.Max(32, size.Height + 8); if (Height != height) Height = height; }
}
