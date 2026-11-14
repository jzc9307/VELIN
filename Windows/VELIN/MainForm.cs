using Message = Velin.Core.Message;
using Velin.Core;
namespace Velin.Windows;

internal sealed class MainForm : Form
{
    readonly Controller state;
    readonly Panel updateCard = new() { Width=164, Height=136, BackColor=Theme.Surface };
    readonly Label updateTitle = Theme.Label("Check for updates",11,Theme.Mint), updateDetail = Theme.Label("",9,Theme.Muted);
    readonly ClickButton updateButton;
    readonly UpdateScreen updateScreen;
    readonly Panel body = new() { Dock = DockStyle.Fill, BackColor = Theme.Background };
    readonly FlowLayoutPanel navigation = new() { Dock = DockStyle.Left, Width = 190, FlowDirection = FlowDirection.TopDown, WrapContents = false, Padding = new Padding(12, 18, 12, 12), BackColor = Theme.Sidebar };
    string page = "Overview";
    TextBox? conversation, transcript, notes, status;
    Label? aboutVersionStatus,aboutLatest,aboutChecked;
    ClickButton? aboutRefresh,aboutDownload;
    ClickButton? listenControl, micControl;
    readonly List<Control> speechSettings = [];
    public MainForm(Controller state)
    {
        this.state = state; Text = "VELIN"; ClientSize = new Size(920, 680); MinimumSize = new Size(800, 560); StartPosition = FormStartPosition.CenterScreen; BackColor = Theme.Background; ForeColor = Color.White; Font = Theme.Font(); Icon = Icon.ExtractAssociatedIcon(Environment.ProcessPath!);
        var side=new Panel{Dock=DockStyle.Left,Width=190,BackColor=Theme.Sidebar};navigation.Dock=DockStyle.Fill;navigation.AutoScroll=true;side.Controls.Add(navigation);
        var footer=new Panel{Dock=DockStyle.Bottom,Height=208,BackColor=Theme.Sidebar};updateCard.Location=new Point(12,8);footer.Controls.Add(updateCard);side.Controls.Add(footer);footer.BringToFront();Controls.Add(body);Controls.Add(side);
        updateTitle.AutoSize=false;updateTitle.SetBounds(11,10,142,34);updateDetail.AutoSize=false;updateDetail.SetBounds(11,46,142,34);updateCard.Controls.Add(updateTitle);updateCard.Controls.Add(updateDetail);
        updateButton=new ClickButton("Check now",()=>Run(()=>state.Updates.Available==null?state.Updates.Check():state.Updates.DownloadAndRestart()),true);updateButton.SetBounds(10,89,144,34);updateCard.Controls.Add(updateButton);
        var providerCard=Theme.Label((state.Active?.Provider??"No AI connected")+"\n"+(state.Active?.Model??"Add your first connection"),10,Theme.Muted);providerCard.AutoSize=false;providerCard.SetBounds(22,155,150,43);footer.Controls.Add(providerCard);
        updateScreen=new UpdateScreen(state.Updates);Controls.Add(updateScreen);updateScreen.BringToFront();state.Updates.Changed+=RefreshUpdates;
        state.Updates.CanRestart=()=>!state.Listening&&!state.AudioBusy&&!state.MicActive&&!state.MicBusy&&!state.Generating&&string.IsNullOrWhiteSpace(state.Prompt)&&state.Image==null;
        state.Updates.PrepareRestart=()=>{state.SaveSession();state.SaveConfig();};
        state.Updates.Restart=()=>{state.Quitting=true;state.SaveSession();Application.Exit();};
        navigation.Controls.Add(Theme.Label("V E L I N", 19, Theme.Mint)); navigation.Controls.Add(Theme.Label("Free. Your AI, your choice.", 9, Theme.Muted));
        foreach (var item in new[] { "Overview", "Conversation", "History", "AI Connections", "Personalization", "Audio & Permissions", "Privacy", "About" }) { var name = item; var button = new ClickButton(name, () => OpenPage(name)) { Width = 164, Height = 38 }; navigation.Controls.Add(button); }
        navigation.Controls.Add(new ClickButton("Open assistant", () => state.Overlay?.Reveal(), true) { Width = 164 });
        navigation.Controls.Add(new ClickButton("Quit VELIN", Quit) { Width = 164 });
        state.Changed += RefreshState; Shown += async (_, _) => { OpenPage("Overview"); RefreshUpdates(); await state.Updates.Check(); };
        FormClosing += (_, e) => { if (!state.Quitting) { e.Cancel = true; Hide(); state.Overlay?.Reveal(); } };
    }
    void RefreshUpdates()
    {
        if(IsDisposed)return;var updates=state.Updates;updateTitle.Text=updates.Available==null?updates.Checking?"Checking…":"VELIN updates":"New version · "+updates.Available.Version;updateDetail.Text=updates.Failure??(updates.Available==null?updates.Status:"A little more clarity is ready.");updateButton.Text=updates.Available==null?"Check now":updates.Ready?"Install & restart":"Download & restart";updateButton.Enabled=!updates.Checking&&!updates.Downloading&&(updates.Available==null||updates.CanRestart());updateScreen.Visible=updates.Launching||updates.PresentingDownload;if(updateScreen.Visible)updateScreen.BringToFront();
        if(aboutVersionStatus!=null)aboutVersionStatus.Text=updates.VersionStatus;
        if(aboutLatest!=null)aboutLatest.Text=updates.LatestPublishedVersion==null?"Latest public version: unknown":"Latest on GitHub: v"+updates.LatestPublishedVersion+(updates.LatestPublishedBuild is int build?" · Build "+build:"");
        if(aboutChecked!=null)aboutChecked.Text=updates.Failure??(updates.LastChecked is DateTime checkedAt?"Last checked "+checkedAt.ToString("g"):"Refresh to check GitHub Releases.");
        if(aboutRefresh!=null)aboutRefresh.Enabled=!updates.Checking&&!updates.Downloading&&!updates.Ready;
        if(aboutDownload!=null){aboutDownload.Visible=updates.Available!=null;aboutDownload.Text=updates.Ready?"Install & restart":"Download & restart";aboutDownload.Enabled=!updates.Downloading&&updates.CanRestart();}
    }
    void Quit() { state.Quitting = true; Application.Exit(); }
    void Safe(Action action) { try { action(); } catch (Exception e) { state.SetError(e.Message); MessageBox.Show(this, e.Message, "VELIN", MessageBoxButtons.OK, MessageBoxIcon.Information); } }
    async void Run(Func<Task> action) { try { await action(); } catch (Exception e) { state.SetError(e.Message); } }
    FlowLayoutPanel Page(string title, string subtitle)
    {
        conversation = transcript = notes = status = null; aboutVersionStatus=aboutLatest=aboutChecked=null;aboutRefresh=aboutDownload=null; listenControl = micControl = null; speechSettings.Clear(); foreach (Control old in body.Controls.Cast<Control>().ToArray()) old.Dispose(); body.Controls.Clear(); var flow = Theme.Column(); body.Controls.Add(flow);
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
    void Personalization()
    {
        var flow = Page("Make room for your way of thinking.", "About me is shared across modes. Instructions, response language and files are saved separately for each mode.");
        var about = Theme.Input(state.Config.AboutMe, true); about.Height = 125; Field(flow, "ABOUT ME · YOUR REAL BACKGROUND", about);
        flow.Controls.Add(new ClickButton("Help me write it", () => { using var wizard = new BiographyWizard(state.Config.AboutMe); if (wizard.ShowDialog(this) == DialogResult.OK) about.Text = wizard.BiographyText; }));
        var selectedMode = state.Config.Mode; var mode = Select(Modes.Names, selectedMode); Field(flow, "ASSISTANT MODE", mode);
        var input = Theme.Input(state.Config.ActiveMode.Instructions, true); input.Height = 120; input.ScrollBars = ScrollBars.None; Field(flow, "INSTRUCTIONS FOR " + selectedMode.ToUpperInvariant(), input); var output = Theme.Input(state.Config.ActiveMode.OutputLanguage); Field(flow, "RESPONSE LANGUAGE FOR THIS MODE", output);
        void Save() { state.Config.AboutMe = about.Text; state.Config.ModeContexts[selectedMode].Instructions = input.Text; state.Config.ModeContexts[selectedMode].OutputLanguage = output.Text; state.SaveConfig(); }
        mode.SelectedIndexChanged += (_, _) => Safe(() => { Save(); state.Config.Mode = mode.Text; state.SaveConfig(); Personalization(); });
        flow.Controls.Add(new ClickButton("Save preferences", () => Safe(Save), true));
        var list = new ListBox { Height = 100, BackColor = Theme.Surface, ForeColor = Color.White, Font = Theme.Font() }; Field(flow, "FILES FOR " + selectedMode.ToUpperInvariant(), list);
        void Fill() { list.Items.Clear(); foreach (var item in state.Config.ActiveMode.Files) list.Items.Add(new FileItem(item)); }
        Fill();
        var actions = Theme.Row(); actions.Controls.Add(new ClickButton("Add files", () => Safe(() => { using var picker = new OpenFileDialog { Filter = "Text context|*.txt;*.md;*.json", Multiselect = true }; if (picker.ShowDialog(this) != DialogResult.OK) return; foreach (var path in picker.FileNames) { if (state.Config.ActiveMode.Files.Count >= 20) throw new IOException("Up to 20 files per mode."); if (new FileInfo(path).Length > 10_000_000) throw new IOException("Choose files under 10 MB."); var text = File.ReadAllText(path); state.Config.ActiveMode.Files.Add(new() { Name = Path.GetFileName(path), Text = text[..Math.Min(12000, text.Length)] }); } Save(); Fill(); })));
        actions.Controls.Add(new ClickButton("Remove selected", () => Safe(() => { if (list.SelectedItem is FileItem selected) { state.Config.ActiveMode.Files.RemoveAll(f => f.Id == selected.File.Id); Save(); Fill(); } }))); flow.Controls.Add(actions);
    }
    sealed record FileItem(ContextFile File) { public override string ToString() => File.Name; }
    void Audio()
    {
        var flow = Page("Two controls. Two jobs.", "Listen transcribes computer audio into the meeting panel. Mic dictates only into the top question box, independently. Neither sends a chat request until you press Enter.");
        var controls = Theme.Row(); listenControl = new ClickButton("Start Listen", () => Run(state.ToggleListen)) { Width = 145 }; micControl = new ClickButton("Start Mic", () => Run(state.ToggleMicrophone)) { Width = 145 }; controls.Controls.Add(listenControl); controls.Controls.Add(micControl); flow.Controls.Add(controls);
        status = Theme.Input("", true); status.ReadOnly = true; status.Height = 66; flow.Controls.Add(status);
        var engine = Select(new[] { "Windows Speech · one language", "Local multilingual · mixed languages", "Soniox cloud · mixed languages" }, state.Config.SpeechBackend == "soniox" ? "Soniox cloud · mixed languages" : state.Config.SpeechBackend == "whisper" ? "Local multilingual · mixed languages" : "Windows Speech · one language"); Field(flow, "SPEECH ENGINE", engine);
        int begin = flow.Controls.Count; var country = Select(new[] { "Malaysia" }, "Malaysia"); Field(flow, "COUNTRY", country); flow.Controls.Add(Wrap("Malaysia · English + Bahasa Melayu + 中文. This on-device preset applies to both independent controls. Review mixed speech for recognition mistakes.", Theme.Mint));
        var modelPath = Theme.Input(state.Config.LocalModelPath); Field(flow, "MULTILINGUAL MODEL · GGML .BIN", modelPath); var hint = Theme.Input(state.Config.MixedLanguageHint); Field(flow, "OPTIONAL NAMES OR SPELLING HINTS", hint);
        var downloads = Theme.Column(); var downloadStatus = Wrap("Offline speech models: download once, then select an installed model. Turbo is a larger option to try for mixed speech; accuracy still needs testing.", Theme.Muted); CancellationTokenSource? modelDownload = null;
        var modelButtons = new Dictionary<SpeechModel,ClickButton>(); var installed = new HashSet<string>();
        void ModelLabels() { foreach(var pair in modelButtons) { var selected=installed.Contains(pair.Key.Id)&&modelPath.Text==pair.Key.PathOnDisk; pair.Value.Text=selected?"Selected ✓":installed.Contains(pair.Key.Id)?"Use installed":"Download";pair.Value.Enabled=!selected&&modelDownload==null; } }
        async Task CheckModels() { foreach(var item in ModelDownloads.Models) if(await ModelDownloads.Installed(item)) installed.Add(item.Id); if(!downloads.IsDisposed) ModelLabels(); }
        async Task Fetch(SpeechModel item) { if(modelDownload!=null)return;using var cancel=new CancellationTokenSource();modelDownload=cancel;ModelLabels();try { modelPath.Text=await ModelDownloads.Fetch(item,new Progress<double>(value=>downloadStatus.Text="Downloading "+item.Name+" · "+Math.Clamp(value,0,1).ToString("P0")),cancel.Token);installed.Add(item.Id);downloadStatus.Text=item.Name+" installed and selected. Save speech settings."; } finally {modelDownload=null;ModelLabels();} }
        foreach(var item in ModelDownloads.Models) { var row=Theme.Row();row.Controls.Add(Wrap(item.Name+" · "+item.Size+" — "+item.Detail,Theme.Muted));var button=new ClickButton("Checking…",()=>Run(()=>Fetch(item))){Enabled=false};modelButtons[item]=button;row.Controls.Add(button);downloads.Controls.Add(row); }
        modelPath.TextChanged+=(_,_)=>ModelLabels();flow.Controls.Add(downloads);var downloadActions=Theme.Row();downloadActions.Controls.Add(new ClickButton("Cancel download",()=>modelDownload?.Cancel()));downloadActions.Controls.Add(new ClickButton("Choose .bin",()=>{using var picker=new OpenFileDialog{Filter="Whisper multilingual model|*.bin"};if(picker.ShowDialog(this)==DialogResult.OK)modelPath.Text=picker.FileName;}));flow.Controls.Add(downloadActions);flow.Controls.Add(downloadStatus);Run(CheckModels);
        var multilingual = flow.Controls.Cast<Control>().Skip(begin).ToArray(); begin = flow.Controls.Count;
        var language = Theme.Input(state.Config.Language); Field(flow, "NATIVE RECOGNITION LANGUAGE · E.G. en-US", language); flow.Controls.Add(Wrap("Windows Speech requires the matching installed local recognizer. Install it in Windows Settings → Time & language → Speech.", Theme.Muted)); var native = flow.Controls.Cast<Control>().Skip(begin).ToArray();
        begin=flow.Controls.Count;
        flow.Controls.Add(Wrap("Soniox cloud · Malaysia: English / Malay / Chinese. Separate speech API key, provider usage charges apply. No local model download is needed.",Theme.Mint));
        var speechKey=Theme.Input();speechKey.UseSystemPasswordChar=true;speechKey.PlaceholderText=CredentialStore.Exists(SonioxProtocol.CredentialId)?"Speech key saved · paste to replace":"Paste Soniox speech API key";Field(flow,"SONIOX SPEECH KEY · WINDOWS CREDENTIAL MANAGER",speechKey);
        flow.Controls.Add(new ClickButton("Save speech key",()=>Safe(()=>{if(!string.IsNullOrWhiteSpace(speechKey.Text)){CredentialStore.Save(SonioxProtocol.CredentialId,speechKey.Text.Trim());speechKey.Text="";speechKey.PlaceholderText="Speech key saved · paste to replace";}})));
        var consent=new CheckBox{Text="Allow audio streaming to Soniox when I start Listen or Mic",Checked=state.Config.SonioxAudioConsent,AutoSize=true,ForeColor=Color.White};flow.Controls.Add(consent);flow.Controls.Add(Wrap("Destination: stt-rt.soniox.com · STT v6. Only started audio controls are streamed; stopping one closes its connection. Provider processing, retention and charges apply. Nothing starts at launch.",Theme.Muted));var cloud=flow.Controls.Cast<Control>().Skip(begin).ToArray();
        void ShowEngine() { foreach (var item in multilingual) item.Visible = engine.SelectedIndex == 1; foreach (var item in native) item.Visible = engine.SelectedIndex == 0; foreach(var item in cloud)item.Visible=engine.SelectedIndex==2; }
        engine.SelectedIndexChanged += (_, _) => ShowEngine(); ShowEngine();
        bool active = state.Listening || state.AudioBusy || state.MicActive || state.MicBusy; speechSettings.Add(engine); speechSettings.AddRange(multilingual.Concat(native).Concat(cloud));
        flow.Controls.Add(new ClickButton("Save speech settings", () => Safe(() => { if (state.Listening || state.AudioBusy || state.MicActive || state.MicBusy) throw new InvalidOperationException("Stop Listen and Mic to change speech settings."); if (engine.SelectedIndex == 0) System.Globalization.CultureInfo.GetCultureInfo(language.Text.Trim()); state.Config.Language = language.Text.Trim(); state.Config.SpeechBackend = engine.SelectedIndex == 2 ? "soniox" : engine.SelectedIndex == 1 ? "whisper" : "windows"; state.Config.SonioxAudioConsent=consent.Checked; state.Config.SpeechCountry = "MY"; state.Config.LocalModelPath = modelPath.Text.Trim(); state.Config.MixedLanguageHint = hint.Text; state.SaveConfig(); }), true));
        if (active) flow.Controls.Add(Wrap("Stop Listen and Mic to change the speech engine, country or model.", Theme.Muted));
    }
    void Privacy()
    {
        var flow = Page("You’re in control.", "Only start Listen when you intend to capture audio. Screenshots are attached for review and are sent only when you explicitly ask."); flow.Controls.Add(Wrap("API keys: Windows Credential Manager, scoped to your Windows account.\nSessions: %LOCALAPPDATA%\\VELIN. No separate session encryption.\nAI: relevant transcript, chat, instructions and screenshot go to your selected provider when you ask. Provider terms apply. Optional Soniox cloud speech sends audio from started controls to Soniox separately; offline engines do not upload audio."));
        var protect = new CheckBox { Text = "Request exclusion from supported Windows capture APIs", AutoSize = true, ForeColor = Color.White, Checked = state.Config.CaptureProtection }; protect.CheckedChanged += (_, _) => Safe(() => { state.Config.CaptureProtection = protect.Checked; state.SaveConfig(); }); flow.Controls.Add(protect); flow.Controls.Add(Wrap("Capture exclusion is best effort, not universal invisibility. Some sharing tools, cameras, remote sessions and exclusive full-screen apps behave differently. The preview keeps a tray icon and Ctrl+Alt+Space recovery.", Theme.Muted));
    }
    void About()
    {
        var flow=Page("About VELIN",$"Installed v{AppUpdates.Version} · Build {AppUpdates.Build} · Windows x64 preview");
        flow.Controls.Add(Wrap("Free and open source. No VELIN subscription.",Theme.Mint));
        aboutVersionStatus=Wrap(state.Updates.VersionStatus,Theme.Mint);flow.Controls.Add(aboutVersionStatus);aboutLatest=Wrap("",Theme.Muted);flow.Controls.Add(aboutLatest);aboutChecked=Wrap("",Theme.Muted);flow.Controls.Add(aboutChecked);
        var actions=Theme.Row();aboutRefresh=new ClickButton("Refresh",()=>Run(state.Updates.Check));actions.Controls.Add(aboutRefresh);aboutDownload=new ClickButton("Download & restart",()=>Run(state.Updates.DownloadAndRestart),true);actions.Controls.Add(aboutDownload);flow.Controls.Add(actions);
        flow.Controls.Add(Theme.Label("What’s new in v"+AppUpdates.Version,16,Theme.Mint));flow.Controls.Add(Wrap(AppUpdates.CurrentReleaseNotes,Theme.Muted));
        flow.Controls.Add(Wrap("Original VELIN code and artwork · MIT license. Provider charges may apply. This Windows build was cross-compiled on macOS. Windows live audio, focus, update/restart and antivirus acceptance still need testing on Windows. It is unsigned.",Theme.Muted));flow.Controls.Add(new ClickButton("Licenses and notices",ShowLicenses));RefreshUpdates();
    }
    void ShowLicenses() { using var stream = typeof(MainForm).Assembly.GetManifestResourceStream("ThirdPartyNotices"); if (stream == null) { state.SetError("Use the release ZIP for the license notices."); return; } using var reader = new StreamReader(stream); using var window = new Form { Text = "VELIN · Licenses and notices", Size = new Size(760, 560), BackColor = Theme.Background, StartPosition = FormStartPosition.CenterParent }; var text = Theme.Input(reader.ReadToEnd(), true); text.Dock = DockStyle.Fill; text.ReadOnly = true; text.ScrollBars = ScrollBars.None; window.Controls.Add(text); window.ShowDialog(this); }
    void Export() => Safe(() => { using var picker = new SaveFileDialog { Filter = "Markdown|*.md", FileName = "VELIN-session.md" }; if (picker.ShowDialog(this) == DialogResult.OK) File.WriteAllText(picker.FileName, state.Session.Markdown()); });
    void RefreshState()
    {
        if (IsDisposed || !Visible) return; RefreshUpdates(); Text = "VELIN · " + page;
        if (listenControl != null) { listenControl.Text = state.AudioBusy ? "Connecting…" : state.Listening ? "Stop Listen" : "Start Listen"; listenControl.Enabled = !state.AudioBusy; listenControl.Primary = state.Listening; }
        if (micControl != null) { micControl.Text = state.MicBusy ? "Starting…" : state.MicActive ? "Stop Mic" : "Start Mic"; micControl.Enabled = !state.MicBusy; micControl.Primary = state.MicActive; }
        foreach (var control in speechSettings) control.Enabled = !(state.Listening || state.AudioBusy || state.MicActive || state.MicBusy);

        void Set(TextBox? box, string text) { if (box != null && box.Text != text) { var caret = box.SelectionStart; box.Text = text; box.SelectionStart = Math.Min(caret, text.Length); } }
        Set(conversation, string.Join("\r\n\r\n", state.Session.Messages.Select(m => (m.Role == "user" ? "You" : "VELIN") + ": " + m.Text))); Set(transcript, string.Join("\r\n", state.Session.Transcript.Select(t => t.Source + ": " + t.Text))); if (state.Generating) Set(notes, state.Session.Notes); Set(status, state.Status + "\r\n" + state.Error + "\r\nMic: " + state.MicStatus);
    }
    protected override void Dispose(bool disposing) { if (disposing) { state.Changed -= RefreshState; state.Updates.Changed-=RefreshUpdates; } base.Dispose(disposing); }
}
