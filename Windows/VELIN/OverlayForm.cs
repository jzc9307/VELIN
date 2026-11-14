using System.Runtime.InteropServices;
using Velin.Core;
namespace Velin.Windows;

internal sealed class OverlayForm : Form
{
    readonly Controller state;
    readonly TextBox prompt = Theme.Input();
    readonly TextBox heard = Theme.Input("", true);
    readonly RichTextBox answer = new() { ReadOnly = true, DetectUrls = false, ScrollBars = RichTextBoxScrollBars.None, BorderStyle = BorderStyle.None, BackColor = Theme.Background, ForeColor = Color.White, Font = Theme.Font(12), Dock = DockStyle.Fill };
    readonly Label question = Theme.Label("", 10, Theme.Muted), audioStatus = Theme.Label("", 9, Theme.Mint), error = Theme.Label("", 9, Theme.Lilac);
    readonly FlowLayoutPanel stack = new() { Dock = DockStyle.Top, FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoSize = true, Padding = new Padding(12), BackColor = Theme.Background };
    readonly Panel audioPanel = new() { Height = 128 }, imagePanel = new() { Height = 90 }, answerPanel = new() { Height = 280 };
    readonly PictureBox preview = new() { Width = 116, Height = 74, SizeMode = PictureBoxSizeMode.Zoom, Dock = DockStyle.Left };
    readonly ClickButton listen, mode, provider, expand, send, microphone;
    readonly NotifyIcon tray;
    readonly FlowLayoutPanel chips = Theme.Row();
    readonly System.Windows.Forms.Timer animation = new() { Interval = 15 };
    string displayedReply = "";
    bool updating, expanded, animating; int fromHeight, targetHeight; DateTime animationStart; string answerView = "Answer"; Guid? shownAnswer; byte[]? shownImage; bool appliedProtection;
    const int BaseHeight = 126;
    public OverlayForm(Controller state)
    {
        this.state = state; Text = "VELIN Assistant"; FormBorderStyle = FormBorderStyle.None; ShowInTaskbar = false; TopMost = true; BackColor = Theme.Background; ForeColor = Color.White; Font = Theme.Font(); StartPosition = FormStartPosition.Manual; ClientSize = new Size(760, BaseHeight); MinimumSize = new Size(760, BaseHeight); Icon = Icon.ExtractAssociatedIcon(Environment.ProcessPath!);
        var area = Screen.PrimaryScreen!.WorkingArea; Location = new Point(Math.Max(area.Left, area.Right - Width - 24), area.Top + 32); Controls.Add(stack);
        var inputRow = new Panel { Height = 44 }; prompt.BorderStyle = BorderStyle.None; prompt.Font = Theme.Font(13); prompt.PlaceholderText = "Ask about your screen or conversation…"; prompt.Dock = DockStyle.Fill; prompt.Margin = new Padding(4); prompt.MaxLength = 16000;
        prompt.TextChanged += (_, _) => { if (!updating) state.Prompt = prompt.Text; }; prompt.KeyDown += (_, e) => { if (e.KeyCode == Keys.Enter) { e.SuppressKeyPress = true; Run(() => state.Ask()); } else if (e.KeyCode == Keys.Escape) Hide(); };
        send = new ClickButton("↵", () => Run(() => state.Ask()), true) { Dock = DockStyle.Right, Width = 48, Height = 38 }; inputRow.Controls.Add(prompt); inputRow.Controls.Add(send); stack.Controls.Add(inputRow);
        var toolbar = Theme.Row(); toolbar.WrapContents = false; toolbar.AutoSize = false; toolbar.Height = 48;
        var logo = new ClickButton("V", () => state.Main?.OpenPage("Overview")) { Width = 34 }; logo.MouseDown += (_, e) => { if (e.Button == MouseButtons.Left && e.Clicks == 2) Native.Drag(this); }; toolbar.Controls.Add(logo);
        toolbar.Controls.Add(new ClickButton("▣", () => Run(state.Capture)) { Width = 36, AccessibleName = "Attach screenshot" });
        listen = new ClickButton("Listen", () => Run(state.ToggleListen)); toolbar.Controls.Add(listen);
        microphone = new ClickButton("Mic", () => Run(state.ToggleMicrophone)) { Width = 40 }; toolbar.Controls.Add(microphone);
        mode = new ClickButton("Meeting ▾", ChooseMode); provider = new ClickButton("AI ▾", ChooseProvider); toolbar.Controls.Add(mode); toolbar.Controls.Add(provider);
        toolbar.Controls.Add(new ClickButton("History", () => state.Main?.OpenPage("History")) { Width = 58 });
        toolbar.Controls.Add(new ClickButton("⚙", () => state.Main?.OpenPage("AI Connections")));
        expand = new ClickButton("⌄", () => { expanded = !expanded; Render(); }); toolbar.Controls.Add(expand); toolbar.Controls.Add(new ClickButton("×", Hide)); stack.Controls.Add(toolbar);
        audioStatus.Dock = DockStyle.Top; audioStatus.AutoSize = false; audioStatus.Height = 26; audioPanel.Controls.Add(audioStatus);
        heard.Dock = DockStyle.Fill; heard.Height = 66; heard.ScrollBars = ScrollBars.None; heard.MaxLength = 6000; heard.PlaceholderText = "The other side’s words appear here. Click to correct before answering."; heard.TextChanged += (_, _) => { if (!updating) { state.Heard.Edit(heard.Text); state.Notify(); } }; heard.KeyDown += (_, e) => { if (e.KeyCode == Keys.Enter && !e.Shift) { e.SuppressKeyPress = true; Run(() => state.Ask()); } };
        var heardHost = new Panel { Dock = DockStyle.Fill, Padding = new Padding(0, 28, 0, 34) }; heardHost.Controls.Add(heard); audioPanel.Controls.Add(heardHost); heardHost.BringToFront();
        var liveActions = Theme.Row(); liveActions.Dock = DockStyle.Bottom; liveActions.Height = 32; liveActions.AutoSize = false; liveActions.Controls.Add(new ClickButton("Resume live", () => { state.Heard.Resume(); Render(); })); liveActions.Controls.Add(new ClickButton("Answer ↵", () => Run(() => state.Ask()), true)); liveActions.Controls.Add(new ClickButton("Transcript", () => state.Main?.OpenPage("Conversation"))); audioPanel.Controls.Add(liveActions); liveActions.BringToFront(); audioStatus.BringToFront(); stack.Controls.Add(audioPanel);
        imagePanel.Controls.Add(preview); var caption = Theme.Label("Screenshot attached · sent only when you ask", 10, Theme.Mint); caption.Dock = DockStyle.Fill; imagePanel.Controls.Add(caption); imagePanel.Controls.Add(new ClickButton("Remove", state.RemoveImage) { Dock = DockStyle.Right, Width = 90 }); stack.Controls.Add(imagePanel);
        question.Dock = DockStyle.Top; question.AutoSize = false; question.Height = 42; question.AutoEllipsis = true; question.Padding = new Padding(0, 8, 0, 0); answerPanel.Controls.Add(answer); answerPanel.Controls.Add(question);
        chips.Dock = DockStyle.Bottom; chips.AutoSize = false; chips.Height = 46; foreach (var label in new[] { "Answer", "Say this", "Next step", "Explain more" }) { var selected = label; chips.Controls.Add(new ClickButton(selected, () => { answerView = selected; RenderAnswer(); })); }
        chips.Controls.Add(new ClickButton("Copy", () => Safe(() => { if (answer.Text.Length > 0) Clipboard.SetText(answer.Text); }))); answerPanel.Controls.Add(chips); stack.Controls.Add(answerPanel);
        error.AutoSize = false; error.Height = 42; error.MaximumSize = new Size(720, 42); error.AutoEllipsis = true; stack.Controls.Add(error);
        stack.ControlAdded += (_, e) => { if (e.Control != null) e.Control.Width = ClientSize.Width - 24; }; Resize += (_, _) => { foreach (Control c in stack.Controls) c.Width = ClientSize.Width - 24; using var path = Theme.Rounded(new RectangleF(0, 0, Width, Height), 20); var old = Region; Region = new Region(path); old?.Dispose(); };
        foreach (Control c in stack.Controls) c.Width = ClientSize.Width - 24;
        var trayMenu = new ContextMenuStrip(); trayMenu.Items.Add("Show assistant", null, (_, _) => Reveal()); trayMenu.Items.Add("Start / stop Listen", null, (_, _) => Run(state.ToggleListen)); trayMenu.Items.Add("Workspace / settings", null, (_, _) => state.Main?.OpenPage("Overview")); trayMenu.Items.Add("Quit VELIN", null, (_, _) => { state.Quitting = true; Application.Exit(); });
        tray = new NotifyIcon { Icon = Icon, Text = "VELIN · Ctrl+Alt+Space", ContextMenuStrip = trayMenu, Visible = true }; tray.DoubleClick += (_, _) => Reveal();
        chips.Controls.Add(new ClickButton("Yes, continue", () => Run(() => state.ContinueReply(displayedReply))) { Width = 130 });
        animation.Tick += (_, _) => { var t = Math.Clamp((DateTime.UtcNow - animationStart).TotalMilliseconds / 220, 0, 1); var ease = 1 - Math.Pow(1 - t, 3); Height = (int)Math.Round(fromHeight + (targetHeight - fromHeight) * ease); if (t >= 1) { animation.Stop(); animating = false; } };
        state.Changed += Render; FormClosing += (_, e) => { if (!state.Quitting) { e.Cancel = true; Hide(); } }; Render();
    }
    public void Reveal() { Show(); Render(); BringToFront(); Activate(); FocusPrompt(); }
    public void FocusPrompt() { if (Visible) { Activate(); prompt.Focus(); prompt.SelectionStart = prompt.TextLength; } }
    public void ExpandAnswer() { expanded = true; answerView = "Answer"; Render(); }
    async void Run(Func<Task> action) { try { await action(); } catch (Exception e) { state.SetError(e.Message); } }
    void Safe(Action action) { try { action(); } catch (Exception e) { state.SetError(e.Message); } }
    void ChooseMode() { var menu = new ContextMenuStrip(); foreach (var item in Modes.Names) { var value = item; menu.Items.Add(value, null, (_, _) => Safe(() => { state.Config.Mode = value; state.SaveConfig(); })); } menu.Show(mode, new Point(0, mode.Height)); }
    void ChooseProvider() { var menu = new ContextMenuStrip(); foreach (var item in state.Config.Profiles) { var value = item; menu.Items.Add(item.Name + " · " + item.Provider, null, (_, _) => Safe(() => { state.Config.ActiveProfileId = value.Id; state.SaveConfig(); })); } menu.Items.Add("Manage connections…", null, (_, _) => state.Main?.OpenPage("AI Connections")); menu.Show(provider, new Point(0, provider.Height)); }
    void ResizeBelow(int height) { if (height == targetHeight && (animating || Height == height)) return; fromHeight = Height; targetHeight = height; animationStart = DateTime.UtcNow; if (!Visible || !SystemInformation.IsMenuAnimationEnabled) { animation.Stop(); animating = false; Height = height; } else { animating = true; animation.Start(); } }
    void Render()
    {
        if (IsDisposed) return; updating = true; try
        {
            if (prompt.Text != state.Prompt) { prompt.Text = state.Prompt; prompt.SelectionStart = prompt.TextLength; }
            prompt.PlaceholderText=state.MicActive?"Speak your question…":"Ask about your screen or conversation…";
            var showAudio = state.Listening || state.AudioBusy; audioPanel.Visible = showAudio;
            if ((!heard.Focused || !state.Heard.IsEdited) && heard.Text != state.Heard.Text) { heard.Text = state.Heard.Text; heard.SelectionStart = heard.TextLength; heard.ScrollToCaret(); }
            audioStatus.Text = (state.Heard.IsEdited ? "Your correction · " : "") + state.Status + $"    Computer {state.ComputerLevel:P0}";
            listen.Text = state.AudioBusy ? "Starting…" : state.Listening ? "Stop" : "Listen"; listen.Width = 76; listen.Enabled = !state.AudioBusy; listen.Primary = state.Listening;
            mode.Text = state.Config.Mode + " ▾"; mode.Width = 110; microphone.Primary = state.MicActive; microphone.Enabled = !state.MicBusy; microphone.Text = state.MicBusy ? "…" : "Mic"; provider.Text = (state.Active?.Provider ?? "AI") + " ▾"; provider.Width = 90; send.Enabled = !state.Generating; expand.Text = expanded ? "⌃" : "⌄";
            imagePanel.Visible = state.Image != null; if (!ReferenceEquals(shownImage, state.Image)) { shownImage = state.Image; var old = preview.Image; preview.Image = null; old?.Dispose(); if (shownImage != null) { using var stream = new MemoryStream(shownImage); using var bitmap = Image.FromStream(stream); preview.Image = new Bitmap(bitmap); } }
            answerPanel.Visible = expanded && state.Session.Messages.Any(m => m.Role == "assistant"); RenderAnswer();
            error.Text = state.Error; error.Visible = state.Error.Length > 0;
            if (IsHandleCreated && appliedProtection != state.Config.CaptureProtection) { if (Native.SetWindowDisplayAffinity(Handle, state.Config.CaptureProtection ? 0x11u : 0u)) appliedProtection = state.Config.CaptureProtection; else { error.Text = "Windows could not apply capture exclusion. Do not assume the bar is excluded."; error.Visible = true; } }
            ResizeBelow(BaseHeight + (showAudio ? 128 : 0) + (imagePanel.Visible ? 90 : 0) + (answerPanel.Visible ? 280 : 0) + (error.Visible ? 42 : 0));
        }
        finally { updating = false; }
    }
    void RenderAnswer()
    {
        var latest = state.Session.Messages.LastOrDefault(m => m.Role == "assistant"); if (latest == null) { answer.Clear(); question.Text = ""; return; }
        var user = state.Session.Messages.TakeWhile(m => m.Id != latest.Id).LastOrDefault(m => m.Role == "user"); question.Text = "You · " + user?.Text;
        var text = answerView switch { "Say this" => latest.Extras?.Say, "Next step" => latest.Extras?.Next, "Explain more" => latest.Extras?.More, _ => latest.Text }; if (string.IsNullOrWhiteSpace(text)) text = state.Generating ? "Preparing this view in the current response…" : "This response did not include that view.";
        foreach (Control control in chips.Controls) if (control is ClickButton button) { if(button.Text=="Yes, continue")button.Visible=answerView=="Next step"; button.Enabled = button.Text switch { "Say this" => !string.IsNullOrWhiteSpace(latest.Extras?.Say), "Next step" => !string.IsNullOrWhiteSpace(latest.Extras?.Next), "Explain more" => !string.IsNullOrWhiteSpace(latest.Extras?.More), "Yes, continue" => answerView=="Next step" && !state.Generating && !string.IsNullOrWhiteSpace(text), _ => true }; }
        displayedReply = text ?? "";
        var prior = state.Session.Messages.TakeWhile(m => m.Id != latest.Id).Select(m => (m.Role == "user" ? "YOU" : "VELIN") + "\r\n" + m.Text);
        var history = string.Join("\r\n\r\n", prior); var anchor = history.LastIndexOf("YOU\r\n", StringComparison.Ordinal); text = history + "\r\n\r\nVELIN\r\n" + text;
        question.Text = "Scroll up for earlier turns";
        if (answer.Text == text) return; var newAnswer = shownAnswer != latest.Id; var selection = answer.SelectionStart; var length = answer.SelectionLength; var scroll = Native.FirstVisibleLine(answer.Handle); answer.Text = text; answer.Select(newAnswer ? Math.Max(0, anchor) : Math.Min(selection, text.Length), newAnswer ? 0 : Math.Min(length, text.Length - Math.Min(selection, text.Length))); if (newAnswer) { answer.ScrollToCaret(); shownAnswer = latest.Id; } else Native.ScrollLines(answer.Handle, scroll - Native.FirstVisibleLine(answer.Handle));
    }
    protected override void OnHandleCreated(EventArgs e) { base.OnHandleCreated(e); var ok = true; var keys = new[] { Keys.Space, Keys.Enter, Keys.L, Keys.S }; for (int i = 0; i < keys.Length; i++) ok &= Native.RegisterHotKey(Handle, 701 + i, 0x4003, (uint)keys[i]); if (!ok) state.SetError("A VELIN shortcut is already used by another app. Use the tray controls."); if (Native.SetWindowDisplayAffinity(Handle, state.Config.CaptureProtection ? 0x11u : 0u)) appliedProtection = state.Config.CaptureProtection; else if (state.Config.CaptureProtection) state.SetError("Windows could not apply capture exclusion. Do not assume the bar is excluded."); }
    protected override void OnHandleDestroyed(EventArgs e) { for (int i = 0; i < 4; i++) Native.UnregisterHotKey(Handle, 701 + i); base.OnHandleDestroyed(e); }
    protected override void WndProc(ref System.Windows.Forms.Message m) { if (m.Msg == 0x0312) { switch ((int)m.WParam) { case 701: if (Visible) Hide(); else Reveal(); break; case 702: Run(() => state.Ask()); break; case 703: Run(state.ToggleListen); break; case 704: Run(state.Capture); break; } } base.WndProc(ref m); }
    protected override void OnMouseDown(MouseEventArgs e) { base.OnMouseDown(e); if (e.Button == MouseButtons.Left) Native.Drag(this); }
    protected override void Dispose(bool disposing) { if (disposing) { state.Changed -= Render; animation.Dispose(); tray.Visible = false; tray.Dispose(); preview.Image?.Dispose(); } base.Dispose(disposing); }
}
