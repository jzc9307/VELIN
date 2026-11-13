using Message = Velin.Core.Message;
using Velin.Core;
namespace Velin.Windows;

internal sealed class MainForm : Form
{
    readonly Controller state;
    readonly Panel body = new() { Dock = DockStyle.Fill, BackColor = Theme.Background };
    readonly FlowLayoutPanel navigation = new() { Dock = DockStyle.Left, Width = 190, FlowDirection = FlowDirection.TopDown, WrapContents = false, Padding = new Padding(12, 18, 12, 12), BackColor = Theme.Sidebar };
    string page = "Overview";
    TextBox? conversation, transcript, notes, status;
    public MainForm(Controller state)
    {
        this.state = state; Text = "VELIN"; ClientSize = new Size(920, 680); MinimumSize = new Size(800, 560); StartPosition = FormStartPosition.CenterScreen; BackColor = Theme.Background; ForeColor = Color.White; Font = Theme.Font(); Icon = Icon.ExtractAssociatedIcon(Environment.ProcessPath!);
        Controls.Add(body); Controls.Add(navigation);
        navigation.Controls.Add(Theme.Label("V E L I N", 19, Theme.Mint)); navigation.Controls.Add(Theme.Label("Free. Your AI, your choice.", 9, Theme.Muted));
        foreach (var item in new[] { "Overview", "Conversation", "History", "AI Connections", "Personalization", "Audio & Permissions", "Privacy", "About" }) { var name = item; var button = new ClickButton(name, () => OpenPage(name)) { Width = 164, Height = 38 }; navigation.Controls.Add(button); }
        navigation.Controls.Add(new ClickButton("Open assistant", () => state.Overlay?.Reveal(), true) { Width = 164 });
        navigation.Controls.Add(new ClickButton("Quit VELIN", Quit) { Width = 164 });
        state.Changed += RefreshState; Shown += (_, _) => { OpenPage("Overview"); state.Overlay?.Reveal(); };
        FormClosing += (_, e) => { if (!state.Quitting) { e.Cancel = true; Hide(); state.Overlay?.Reveal(); } };
    }
    void Quit() { state.Quitting = true; Application.Exit(); }
    void Safe(Action action) { try { action(); } catch (Exception e) { state.SetError(e.Message); MessageBox.Show(this, e.Message, "VELIN", MessageBoxButtons.OK, MessageBoxIcon.Information); } }
    async void Run(Func<Task> action) { try { await action(); } catch (Exception e) { state.SetError(e.Message); } }
    FlowLayoutPanel Page(string title, string subtitle)
    {
        conversation = transcript = notes = status = null; foreach (Control old in body.Controls.Cast<Control>().ToArray()) old.Dispose(); body.Controls.Clear(); var flow = Theme.Column(); body.Controls.Add(flow);
        flow.ControlAdded += (_, e) => { if (e.Control != null) e.Control.Width = Math.Max(100, flow.ClientSize.Width - 56); }; flow.SizeChanged += (_, _) => { foreach (Control c in flow.Controls) c.Width = Math.Max(100, flow.ClientSize.Width - 56); };
        flow.Controls.Add(Theme.Label(title, 22)); flow.Controls.Add(Wrap(subtitle, Theme.Muted)); return flow;
    }
    static Label Wrap(string text, Color? color = null) => new WrappedLabel { Text = text, ForeColor = color ?? Color.White, Font = Theme.Font(), Margin = new Padding(0, 8, 0, 12) };
    static ComboBox Select(IEnumerable<string> choices, string selected) { var box = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Font = Theme.Font(), BackColor = Theme.Surface, ForeColor = Color.White, Height = 32, Margin = new Padding(0, 4, 0, 14) }; box.Items.AddRange(choices.Cast<object>().ToArray()); box.SelectedItem = selected; if (box.SelectedIndex < 0 && box.Items.Count > 0) box.SelectedIndex = 0; return box; }
    static void Field(FlowLayoutPanel flow, string label, Control control) { flow.Controls.Add(Theme.Label(label, 9, Theme.Muted)); flow.Controls.Add(control); }
    public void OpenPage(string name)
    {
        page = name; Show(); Activate();
        switch (name) { case "Overview": Overview(); break; case "Conversation": Conversation(); break; case "History": History(); break; case "AI Connections": Connections(); break; case "Personalization": Personalization(); break; case "Audio & Permissions": Audio(); break; case "Privacy": Privacy(); break; default: About(); break; }
        RefreshState();
    }
    void Overview()
    {
        var flow = Page("A little clarity.", "A free assistant for the conversation, right when you need it. Windows preview — please test before relying on it in a call.");
        flow.Controls.Add(new ClickButton("Open your assistant", () => state.Overlay?.Reveal(), true));
        flow.Controls.Add(new ClickButton("Set up AI connections", () => OpenPage("AI Connections")));
        flow.Controls.Add(new ClickButton("Set up local audio", () => OpenPage("Audio & Permissions")));
        flow.Controls.Add(Wrap("1. Save your provider and key.  2. Start Listen while the call runs on this PC.  3. Correct the other side’s words if needed, then press Enter in VELIN.\n\nAPI usage is billed by your provider; VELIN itself has no subscription."));
        flow.Controls.Add(Wrap("Ctrl + Alt + Space  ·  Show / hide\nCtrl + Alt + Enter  ·  Answer the pending question\nCtrl + Alt + L  ·  Listen    |    Ctrl + Alt + S  ·  Screenshot"));
    }
    void Conversation()
    {
        var flow = Page(state.Session.Title, "The full conversation, transcript and notes stay on this PC. Use the floating assistant to ask or edit the live question.");
        var row = Theme.Row(); row.Controls.Add(new ClickButton("New session", () => Safe(state.NewSession))); row.Controls.Add(new ClickButton("Export Markdown", Export)); row.Controls.Add(new ClickButton("Generate notes", () => Run(() => state.Ask(true)))); flow.Controls.Add(row);
        conversation = Theme.Input("", true); conversation.Height = 180; conversation.ReadOnly = true; conversation.ScrollBars = ScrollBars.None; Field(flow, "CONVERSATION", conversation);
        transcript = Theme.Input("", true); transcript.Height = 140; transcript.ReadOnly = true; transcript.ScrollBars = ScrollBars.None; Field(flow, "TRANSCRIPT · RAW RECOGNITION", transcript);
        notes = Theme.Input(state.Session.Notes, true); notes.Height = 160; notes.ScrollBars = ScrollBars.None; notes.TextChanged += (_, _) => { if (!state.Generating) { state.Session.Notes = notes.Text; state.SaveSession(); } }; Field(flow, "YOUR NOTES", notes);
    }
    void History()
    {
        var flow = Page("Good conversations stay with you.", "Open a saved local session or export it. Stop Listen before switching sessions.");
        var search = Theme.Input(); Field(flow, "SEARCH", search); var list = new ListBox { Height = 270, BackColor = Theme.Surface, ForeColor = Color.White, Font = Theme.Font(), BorderStyle = BorderStyle.FixedSingle }; flow.Controls.Add(list);
        void Fill() { list.Items.Clear(); foreach (var item in state.Sessions.Where(s => (s.Title + " " + string.Join(" ", s.Messages.Select(m => m.Text))).Contains(search.Text, StringComparison.OrdinalIgnoreCase))) list.Items.Add(new SessionItem(item)); }
        search.TextChanged += (_, _) => Fill(); Fill(); var row = Theme.Row(); row.Controls.Add(new ClickButton("Open session", () => Safe(() => { if (list.SelectedItem is SessionItem item) { state.OpenSession(item.Session); OpenPage("Conversation"); } }))); row.Controls.Add(new ClickButton("Export current session", Export)); flow.Controls.Add(row);
    }
    sealed record SessionItem(Session Session) { public override string ToString() => Session.Created.ToString("g") + "  ·  " + Session.Title; }
    void Connections(Guid? selected = null)
    {
        var flow = Page("Your AI. Your choice.", "Keep up to five connections. Keys are stored in Windows Credential Manager. Blank replacement fields preserve existing keys.");
        var row = Theme.Row(); var choose = new ComboBox { Width = 220, DropDownStyle = ComboBoxStyle.DropDownList, Font = Theme.Font() }; foreach (var p in state.Config.Profiles) choose.Items.Add(new ProfileItem(p)); choose.SelectedItem = choose.Items.Cast<ProfileItem>().FirstOrDefault(p => p.Profile.Id == (selected ?? state.Active?.Id)); choose.SelectedIndexChanged += (_, _) => { if (choose.SelectedItem is ProfileItem p) Connections(p.Profile.Id); }; row.Controls.Add(choose);
        row.Controls.Add(new ClickButton("+ Add connection", () => { if (state.Config.Profiles.Count >= 5) { state.SetError("Five connections maximum."); return; } ConnectionEditor(flow, new Profile { Name = "Connection " + (state.Config.Profiles.Count + 1) }); })); flow.Controls.Add(row);
        ConnectionEditor(flow, state.Config.Profiles.FirstOrDefault(p => p.Id == (selected ?? state.Active?.Id)) ?? new Profile { Name = "Connection " + (state.Config.Profiles.Count + 1) });
    }
    sealed record ProfileItem(Profile Profile) { public override string ToString() => Profile.Name; }
    void ConnectionEditor(FlowLayoutPanel flow, Profile profile)
    {
        while (flow.Controls.Count > 3) { var old = flow.Controls[3]; flow.Controls.Remove(old); old.Dispose(); }
        var name = Theme.Input(profile.Name); Field(flow, "CONNECTION NAME", name); var provider = Select(Providers.Names, profile.Provider); Field(flow, "AI PROVIDER", provider); var model = Theme.Input(profile.Model); Field(flow, "MODEL ID · EDITABLE", model); var endpoint = Theme.Input(profile.Endpoint); Field(flow, "API BASE URL", endpoint); var key = Theme.Input(); key.UseSystemPasswordChar = true; key.PlaceholderText = "Paste to save or replace; leave blank to preserve"; Field(flow, "API KEY", key);
        provider.SelectedIndexChanged += (_, _) => { var selected = provider.Text; model.Text = Providers.Model(selected); endpoint.Text = Providers.Endpoint(selected); key.Clear(); };
        var row = Theme.Row(); var result = Wrap("Saving does not send an AI request. Test sends only ‘Connection test. Reply OK.’ and may incur provider charges.", Theme.Muted);
        row.Controls.Add(new ClickButton("Save connection", () => Safe(() => { state.SaveProfile(new Profile { Id = profile.Id, Name = name.Text.Trim(), Provider = provider.Text, Model = model.Text.Trim(), Endpoint = endpoint.Text.Trim() }, key.Text); key.Clear(); result.Text = "Saved and selected. Your key remains in Credential Manager."; }), true));
        row.Controls.Add(new ClickButton("Test saved connection", () => Run(async () => { var saved = state.Config.Profiles.FirstOrDefault(p => p.Id == profile.Id) ?? throw new InvalidOperationException("Save this connection first."); result.Text = "Testing saved connection…"; using var request = AiClient.Request(saved, CredentialStore.Read(saved.Id), "Reply briefly.", [new Message { Text = "Connection test. Reply OK." }], null); using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(45)); var reply = ""; await foreach (var part in AiClient.Stream(request, saved.Provider, timeout.Token)) reply += part; result.Text = "Connection succeeded: " + reply[..Math.Min(100, reply.Length)]; })));
        row.Controls.Add(new ClickButton("Delete", () => Safe(() => { if (MessageBox.Show(this, "Delete this connection and its saved key?", "VELIN", MessageBoxButtons.YesNo) != DialogResult.Yes) return; state.DeleteProfile(profile.Id); Connections(); }))); flow.Controls.Add(row); flow.Controls.Add(result);
    }
    void Personalization() { var flow = Page("Make room for your own voice.", "Your preferences are included when you explicitly ask your chosen AI provider."); var mode = Select(new[] { "General", "Meeting", "Coding", "Study", "Sales", "Custom" }, state.Config.Mode); Field(flow, "DEFAULT MODE", mode); var input = Theme.Input(state.Config.Instructions, true); input.Height = 220; input.ScrollBars = ScrollBars.None; Field(flow, "PERSONAL INSTRUCTIONS", input); flow.Controls.Add(new ClickButton("Save preferences", () => Safe(() => { state.Config.Mode = mode.Text; state.Config.Instructions = input.Text; state.SaveConfig(); }), true)); }
    void Audio()
    {
        var flow = Page("Listen locally.", "Computer audio captures the meeting output on this PC. Microphone captures your side. VELIN transcribes locally with an installed Windows Speech recognizer; it does not automatically ask AI.");
        var mic = new CheckBox { Text = "Microphone · your voice", Checked = state.Config.Microphone, AutoSize = true, ForeColor = Color.White }; var system = new CheckBox { Text = "Computer audio · meeting / default output", Checked = state.Config.ComputerAudio, AutoSize = true, ForeColor = Color.White }; flow.Controls.Add(mic); flow.Controls.Add(system); var language = Theme.Input(state.Config.Language); Field(flow, "RECOGNITION LANGUAGE · E.G. en-US", language);
        flow.Controls.Add(Wrap("Install a matching Windows Speech language first. In Windows Settings → Time & language → Speech, install the speech pack. Online-only dictation languages are not supported by this preview. Restart Listen after changing the meeting’s output device.", Theme.Muted));
        var row = Theme.Row(); row.Controls.Add(new ClickButton("Save audio settings", () => Safe(() => { if (state.Listening || state.AudioBusy) throw new InvalidOperationException("Stop Listen before changing inputs."); if (!mic.Checked && !system.Checked) throw new InvalidOperationException("Select at least one audio source."); System.Globalization.CultureInfo.GetCultureInfo(language.Text.Trim()); state.Config.Microphone = mic.Checked; state.Config.ComputerAudio = system.Checked; state.Config.Language = language.Text.Trim(); state.SaveConfig(); }), true)); row.Controls.Add(new ClickButton("Start / stop Listen", () => Run(state.ToggleListen))); flow.Controls.Add(row);
        status = Theme.Input("", true); status.ReadOnly = true; status.Height = 150; flow.Controls.Add(status);
    }
    void Privacy()
    {
        var flow = Page("You’re in control.", "Only start Listen when you intend to capture audio. Screenshots are attached for review and are sent only when you explicitly ask."); flow.Controls.Add(Wrap("API keys: Windows Credential Manager, scoped to your Windows account.\nSessions: %LOCALAPPDATA%\\VELIN. No separate session encryption.\nAI: relevant transcript, chat, instructions and screenshot go to your selected provider when you ask. Provider terms apply."));
        var protect = new CheckBox { Text = "Request exclusion from supported Windows capture APIs", AutoSize = true, ForeColor = Color.White, Checked = state.Config.CaptureProtection }; protect.CheckedChanged += (_, _) => Safe(() => { state.Config.CaptureProtection = protect.Checked; state.SaveConfig(); }); flow.Controls.Add(protect); flow.Controls.Add(Wrap("Capture exclusion is best effort, not universal invisibility. Some sharing tools, cameras, remote sessions and exclusive full-screen apps behave differently. The preview keeps a tray icon and Ctrl+Alt+Space recovery.", Theme.Muted));
    }
    void About() { var flow = Page("VELIN · Windows preview", $"Version {Application.ProductVersion.Split('+')[0]} · Windows x64 · Free and open source"); flow.Controls.Add(Wrap("Original VELIN code and artwork · MIT license. No VELIN account or subscription. AI provider charges may apply.\n\nThis Windows build was cross-compiled on macOS. Live Windows audio, focus, capture, packaging and antivirus acceptance still need testing on Windows. It is unsigned.")); }
    void Export() => Safe(() => { using var picker = new SaveFileDialog { Filter = "Markdown|*.md", FileName = "VELIN-session.md" }; if (picker.ShowDialog(this) == DialogResult.OK) File.WriteAllText(picker.FileName, state.Session.Markdown()); });
    void RefreshState()
    {
        if (IsDisposed || !Visible) return; Text = "VELIN · " + page;
        void Set(TextBox? box, string text) { if (box != null && box.Text != text) { var caret = box.SelectionStart; box.Text = text; box.SelectionStart = Math.Min(caret, text.Length); } }
        Set(conversation, string.Join("\r\n\r\n", state.Session.Messages.Select(m => (m.Role == "user" ? "You" : "VELIN") + ": " + m.Text))); Set(transcript, string.Join("\r\n", state.Session.Transcript.Select(t => t.Source + ": " + t.Text))); if (state.Generating) Set(notes, state.Session.Notes); Set(status, state.Status + "\r\n" + state.Error + "\r\nYou: " + state.LiveYou + "\r\nComputer: " + state.Heard.LiveText);
    }
    protected override void Dispose(bool disposing) { if (disposing) state.Changed -= RefreshState; base.Dispose(disposing); }
}
