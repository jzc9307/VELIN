import SwiftUI
import AppKit

struct ConnectionsView: View {
    @ObservedObject var model: AppModel
    @ViewState var selected: UUID?
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) { SectionHeading(title: "Your intelligence, connected.", subtitle: "Choose your provider, paste your key, and make it yours. Five slots. One active connection."); Pill(text: "\(model.config.profiles.count) / 5 SLOTS", color: Ink.lilac) }
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 9) {
                    ForEach(model.config.profiles) { profile in
                        Button { selected = profile.id; model.connectionResult = "" } label: {
                            HStack(spacing: 11) { ProviderBadge(provider: profile.provider); VStack(alignment: .leading, spacing: 5) { Text(profile.name).font(.system(size: 12, weight: .semibold)).lineLimit(1); Text(profile.provider.rawValue).font(.system(size: 11)).foregroundStyle(Ink.muted) }; Spacer(minLength: 4); if model.config.activeProfileID == profile.id { Circle().fill(Ink.mint).frame(width: 6, height: 6) } }.padding(13).background(selected == profile.id ? Ink.mint.opacity(0.06) : Ink.surface, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected == profile.id ? Ink.mint.opacity(0.3) : Ink.line))
                        }.buttonStyle(.plain)
                    }
                    ForEach(0..<max(0, 5-model.config.profiles.count), id: \.self) { index in
                        Button { model.addProfile(); selected = model.config.profiles.last?.id } label: { HStack { Image(systemName: "plus").font(.system(size: 13)); Text("Add connection").font(.system(size: 12)); Spacer(); Text("0\(model.config.profiles.count+index+1)").font(.system(size: 10, design: .monospaced)) }.foregroundStyle(Ink.muted).padding(17).background(.white.opacity(0.015), in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Ink.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))) }.buttonStyle(.plain)
                    }
                    Spacer()
                    Label("Keys stay in macOS Keychain", systemImage: "lock.shield").font(.system(size: 10)).foregroundStyle(Ink.muted).padding(.top, 12)
                }.frame(width: 236)
                if let id = selected, let profile = model.config.profiles.first(where: { $0.id == id }) { ConnectionEditor(model: model, original: profile).id(id) }
                else { Card { VStack(alignment: .leading, spacing: 20) { VelinMark().frame(width: 44, height: 44); Text("A familiar AI.\nA more personal workspace.").font(.system(size: 27, weight: .regular, design: .serif)); Text("Connect OpenAI, Claude, Gemini, OpenRouter, Groq, or a local model. You can use several keys from the same provider, too.").font(.system(size: 13)).foregroundStyle(Ink.muted).lineSpacing(5); Text("No key is included. Your provider bills its own usage. ChatGPT and Claude subscriptions do not automatically include API credits.").font(.system(size: 11)).foregroundStyle(Ink.muted); Button("Add your first connection") { model.addProfile(); selected = model.config.profiles.last?.id }.buttonStyle(Press(primary: true)).disabled(model.config.profiles.count >= 5) }.frame(maxHeight: .infinity, alignment: .top) } }
            }.frame(maxHeight: .infinity)
        }.padding(32).onAppear { selected = model.config.activeProfileID ?? model.config.profiles.first?.id }
            .onChange(of: model.config.profiles) { _, profiles in
                if !profiles.contains(where: { $0.id == selected }) { selected = model.config.activeProfileID ?? profiles.first?.id }
            }
    }
}
struct ProviderBadge: View {
    let provider: Provider
    var body: some View {
        Group {
            if let image = NSImage(contentsOf: Bundle.main.resourceURL!.appendingPathComponent("Providers/\(assetName).png")) {
                Image(nsImage: image).resizable().scaledToFit().frame(width: 23, height: 23)
            } else { Image(systemName: "server.rack").font(.system(size: 18)).foregroundStyle(Ink.mint) }
        }.frame(width: 36, height: 36).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 9)).accessibilityLabel(provider.rawValue + " logo")
    }
    var assetName: String {
        switch provider { case .openAI: return "openai"; case .claude: return "claude"; case .gemini: return "gemini"; case .openRouter: return "openrouter"; case .groq: return "groq"; case .ollama: return "ollama"; case .custom: return "custom" }
    }
}
struct ConnectionEditor: View {
    @ObservedObject var model: AppModel
    let original: AIProfile
    @ViewState var draft = AIProfile()
    @ViewState var key = ""
    @ViewState var localMessage = ""
    @ViewState var confirmRemove = false
    @ViewState var loaded = false
    @ViewState var hasSavedKey = false
    init(model: AppModel, original: AIProfile) {
        self.model = model; self.original = original
        _draft = ViewState(initialValue: original)
    }
    var body: some View {
        ScrollView {
            Card { VStack(alignment: .leading, spacing: 18) {
                HStack { ProviderBadge(provider: draft.provider); Text("Connection settings").font(.system(size: 16, weight: .medium)); Spacer(); if model.config.activeProfileID == original.id { Pill(text: "ACTIVE") } }
                field("CONNECTION NAME") { TextField("My connection", text: $draft.name).velinField() }
                field("AI PROVIDER") { Picker("Provider", selection: $draft.provider) { ForEach(Provider.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading) }
                field("MODEL") {
                    HStack { TextField("Model ID", text: $draft.model).velinField(); if !draft.provider.models.isEmpty { Menu { ForEach(draft.provider.models, id: \.self) { value in Button(value) { draft.model = value } } } label: { Image(systemName: "chevron.down") }.menuStyle(.borderlessButton).frame(width: 24) } }
                    Text("Suggested IDs are editable. Availability depends on your provider account.").font(.system(size: 10)).foregroundStyle(Ink.muted)
                }
                field("API BASE URL") { TextField("https://your-provider.example/v1", text: $draft.endpoint).velinField(); Text("The destination that receives your requests. HTTPS required except localhost.").font(.system(size: 10)).foregroundStyle(Ink.muted) }
                field(draft.provider == .ollama ? "API KEY · OPTIONAL FOR LOCAL MODELS" : "API KEY") { SecureField(hasSavedKey ? "Key saved · paste here to replace it" : "Paste your API key", text: $key).velinField().privacySensitive(); Text(hasSavedKey ? "A key is saved in Keychain. Leaving this field blank preserves it." : "Stored for this slot in Keychain, never in the project or an .env file.").font(.system(size: 10)).foregroundStyle(Ink.muted) }
                HStack {
                    Button("Save connection") { do { try model.saveProfile(draft, key: key); key = ""; hasSavedKey = SecretStore.contains(original.id); localMessage = "Saved securely in Keychain." } catch { localMessage = error.localizedDescription } }.buttonStyle(Press(primary: true))
                    Button(model.testingConnection ? "Testing…" : "Test") { model.testConnection(draft, key: key.isEmpty && hasSavedKey ? SecretStore.read(original.id) : key) }.buttonStyle(Press()).disabled(model.testingConnection)
                    Spacer()
                    Button { confirmRemove = true } label: { Image(systemName: "trash") }.buttonStyle(Press()).help("Remove connection")
                }
                if model.config.activeProfileID != original.id { Button("Use this connection") { do { try model.saveProfile(draft, key: key); key = ""; hasSavedKey = SecretStore.contains(original.id); model.config.activeProfileID = original.id; model.saveConfig(); localMessage = "Active connection updated." } catch { localMessage = error.localizedDescription } }.buttonStyle(Press()) }
                if !localMessage.isEmpty { Text(localMessage).font(.system(size: 11)).foregroundStyle(Ink.mint).textSelection(.enabled) }
                if !model.connectionResult.isEmpty { Text(model.connectionResult).font(.system(size: 11)).foregroundStyle(Ink.lilac).textSelection(.enabled) }
                Divider().overlay(Ink.line)
                Text("Test sends only “Connection test. Reply OK.” to this endpoint and may incur a small provider charge. It sends no transcript, documents, or screenshot.").font(.system(size: 10)).foregroundStyle(Ink.muted).lineSpacing(4)
            } }
        }.onAppear { guard !loaded else { return }; hasSavedKey = SecretStore.contains(original.id); loaded = true }
            .onChange(of: draft.provider) { _, provider in guard loaded else { return }; draft.endpoint = provider.endpoint; draft.model = provider.models.first ?? ""; key = ""; hasSavedKey = false; localMessage = "Paste a key for \(provider.rawValue)."; model.connectionResult = "" }
            .alert("Remove this connection?", isPresented: $confirmRemove) { Button("Cancel", role: .cancel) {}; Button("Remove", role: .destructive) { model.deleteProfile(original.id) } } message: { Text("Its API key will be removed from Keychain. Your sessions stay saved.") }
    }
    func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(.system(size: 9, weight: .semibold)).tracking(1.3).foregroundStyle(Ink.muted); content() } }
}

struct PreferencesView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            SectionHeading(title: "Make room for your way of thinking.", subtitle: "Set the tone, bring context, and choose how VELIN helps.")
            Card { VStack(alignment: .leading, spacing: 17) {
                Text("Assistant mode").font(.system(size: 16, weight: .medium))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 125))], spacing: 10) { ForEach(AssistantMode.allCases) { mode in Button { model.config.mode = mode; model.session.mode = mode; model.saveConfig() } label: { Label(mode.rawValue, systemImage: mode.icon).frame(maxWidth: .infinity, minHeight: 40).foregroundStyle(model.config.mode == mode ? Ink.mint : Ink.muted).background(model.config.mode == mode ? Ink.mint.opacity(0.08) : .white.opacity(0.025), in: RoundedRectangle(cornerRadius: 9)) }.buttonStyle(.plain) } }
                Text("Custom instructions").font(.system(size: 12, weight: .medium))
                TextEditor(text: $model.config.customInstruction).font(.system(size: 13)).scrollContentBackground(.hidden).frame(height: 100).padding(10).background(Ink.background, in: RoundedRectangle(cornerRadius: 10))
                TextField("Output language", text: $model.config.outputLanguage).velinField()
                Button("Save preferences") { model.saveConfig(); model.notice = "Preferences saved." }.buttonStyle(Press(primary: true))
            } }
            Card { VStack(alignment: .leading, spacing: 16) {
                HStack { Text("Bring your context").font(.system(size: 16, weight: .medium)); Spacer(); Button { model.importContext() } label: { Label("Add files", systemImage: "plus") }.buttonStyle(Press()) }
                Text("Text, Markdown, JSON, and text-based PDFs. Up to 20 files, 12,000 characters each. Included in questions sent to your selected provider.").font(.system(size: 12)).foregroundStyle(Ink.muted)
                ForEach(model.config.contextFiles) { file in HStack { Image(systemName: "doc.text").foregroundStyle(Ink.lilac); Text(file.name).font(.system(size: 12)); Spacer(); Text("\(file.text.count) chars").font(.system(size: 10)).foregroundStyle(Ink.muted); Button { model.config.contextFiles.removeAll { $0.id == file.id }; model.saveConfig() } label: { Image(systemName: "xmark") }.buttonStyle(.plain).help("Remove context file") } }
            } }
        }.padding(32) }
    }
}
struct PermissionRow: View {
    let icon: String
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void
    var body: some View { HStack(alignment: .top, spacing: 15) { Image(systemName: icon).font(.system(size: 21, weight: .light)).foregroundStyle(granted ? Ink.mint : Ink.muted).frame(width: 30).padding(.top, 3); VStack(alignment: .leading, spacing: 7) { Text(title).font(.system(size: 14, weight: .medium)); Text(detail).font(.system(size: 12)).foregroundStyle(Ink.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true) }; Spacer(minLength: 15); if granted { Image(systemName: "checkmark.circle.fill").foregroundStyle(Ink.mint).font(.system(size: 20)).accessibilityLabel("Allowed") } else { Button("Allow", action: action).buttonStyle(Press()) } }.padding(20).background(Ink.surface.opacity(0.8), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Ink.line)) }
}
struct AudioSettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 22) {
            SectionHeading(title: "Only when you press Listen.", subtitle: "Control the sources and permissions VELIN uses. No audio recording files are retained.")
            permissions
            Card { VStack(alignment: .leading, spacing: 20) {
                Text("Audio sources").font(.system(size: 16, weight: .medium))
                Toggle("Microphone · labeled You", isOn: $model.config.microphone)
                Toggle("Computer audio · labeled Computer", isOn: $model.config.systemAudio)
                Text("Computer audio may include several people. VELIN separates input sources, not individual speakers. Headphones help avoid the same voice reaching both inputs.").font(.system(size: 11)).foregroundStyle(Ink.muted)
                Picker("Transcription language", selection: $model.config.language) { Text("English (US)").tag("en-US"); Text("English (UK)").tag("en-GB"); Text("中文（普通话）").tag("zh-CN"); Text("中文（繁體）").tag("zh-TW"); Text("Bahasa Melayu").tag("ms-MY"); Text("日本語").tag("ja-JP"); Text("Español").tag("es-ES"); Text("Français").tag("fr-FR"); Text("Deutsch").tag("de-DE") }.pickerStyle(.menu)
                Toggle("Require on-device speech recognition", isOn: $model.config.localSpeechOnly)
                Text("When enabled, unsupported on-device languages produce a clear error. Turning this off permits Apple's speech service to process audio according to your system settings. Your selected AI provider receives text only when you ask a question or generate notes.").font(.system(size: 11)).foregroundStyle(Ink.muted).lineSpacing(4)
                Button("Save audio settings") { model.saveConfig(); model.notice = "Audio settings saved. Changes apply the next time you press Listen." }.buttonStyle(Press(primary: true))
            }.toggleStyle(.switch) }.disabled(model.recording || model.startingAudio)
            if model.recording { Text("Stop listening before changing audio sources.").font(.system(size: 12)).foregroundStyle(Ink.mint) }
            HStack { Text("Input level").font(.system(size: 12)); ProgressView(value: model.level).tint(Ink.mint); Text(model.recording ? "LIVE" : "STOPPED").font(.system(size: 9, weight: .bold)).foregroundStyle(Ink.muted) }
        }.padding(32) }.onAppear { model.refreshPermissions() }
    }
    var permissions: some View { VStack(spacing: 10) { PermissionRow(icon: "mic", title: "Microphone", detail: "Transcribe what you say during a session.", granted: model.microphoneAllowed, action: model.requestMicrophone); PermissionRow(icon: "waveform.badge.mic", title: "Speech recognition", detail: "Turn live audio into text using Apple's speech framework.", granted: model.speechAllowed, action: model.requestSpeech); PermissionRow(icon: "display", title: "Screen & system audio", detail: "Capture computer audio during sessions and screenshots when requested.", granted: model.screenAllowed, action: model.requestScreen); HStack { Text("macOS may ask you to quit and reopen after allowing screen recording.").font(.system(size: 10)).foregroundStyle(Ink.muted); Spacer(); Button("Refresh status") { model.refreshPermissions() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Ink.mint) } } }
}
struct PrivacyView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            SectionHeading(title: "A clear view of your privacy.", subtitle: "Know what stays here, what leaves your Mac, and what screen sharing can reveal.")
            Card { VStack(alignment: .leading, spacing: 18) {
                Label("On this Mac", systemImage: "internaldrive").font(.system(size: 16, weight: .medium)).foregroundStyle(Ink.mint)
                Text("Session history, transcripts, notes, and context text stay in Application Support/VELIN. API keys are stored separately in Keychain. VELIN has no analytics, account system, or remote database.").font(.system(size: 13)).foregroundStyle(Ink.muted).lineSpacing(5)
                Button("Open local data folder") { model.revealData() }.buttonStyle(Press())
                Divider()
                Label("When you ask AI", systemImage: "arrow.up.forward.circle").font(.system(size: 16, weight: .medium)).foregroundStyle(Ink.lilac)
                Text("Your question, recent conversation, transcript context, custom instructions, and attached documents go to your active provider. A screenshot is sent only when attached to that question. Screenshots are not saved to history. Provider processing and retention policies still apply.").font(.system(size: 13)).foregroundStyle(Ink.muted).lineSpacing(5)
                Text("Current destination: \(model.endpointHost)").font(.system(size: 11, weight: .medium)).foregroundStyle(Ink.mint)
            } }
            Card { VStack(alignment: .leading, spacing: 16) {
                Toggle("Hidden mode", isOn: $model.config.captureProtection).toggleStyle(.switch).font(.system(size: 14, weight: .medium)).onChange(of: model.config.captureProtection) { _, _ in model.saveConfig() }
                Text("Hides VELIN from the Dock, app switcher, and menu bar, and makes the assistant slightly smaller. Press ⌃⌥Space to show the bar, then click its eye button to restore the icons. You can also reopen VELIN.app to reach this setting. Screen-capture exclusion is best effort; macOS and sharing apps may still capture VELIN. It does not hide the process.").font(.system(size: 12)).foregroundStyle(Ink.muted).lineSpacing(5)
                Link("Read Apple's capture limitation ↗", destination: URL(string: "https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum/none")!).font(.system(size: 11)).foregroundStyle(Ink.lilac)
                HStack { Text("Assistant opacity").font(.system(size: 12)); Slider(value: $model.config.overlayOpacity, in: 0.65...1).tint(Ink.mint).onChange(of: model.config.overlayOpacity) { _, _ in model.saveConfig() }; Text("\(Int(model.config.overlayOpacity*100))%").font(.system(size: 11, design: .monospaced)).frame(width: 40) }
            } }
            Text("Record conversations only when you have the required permission from participants. Local data is protected by your macOS account and disk encryption settings; VELIN does not add a separate database password.").font(.system(size: 11)).foregroundStyle(Ink.muted)
        }.padding(32) }
    }
}
struct AboutView: View {
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 24) { SectionHeading(title: "VELIN", subtitle: "A quieter kind of clarity."); Card { HStack(spacing: 30) { VelinMark().frame(width: 84, height: 84); VStack(alignment: .leading, spacing: 10) { Text("Your context. Your AI. Your Mac.").font(.system(size: 22, weight: .regular, design: .serif)); Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0") · Native SwiftUI & AppKit · Apple Silicon").font(.system(size: 12)).foregroundStyle(Ink.muted); Text("Built independently. Cluely was used as a workflow reference; no Cluely code, services, or branding are bundled.").font(.system(size: 12)).foregroundStyle(Ink.muted).lineSpacing(4) } } }; Card { VStack(alignment: .leading, spacing: 16) { Text("Always within reach").font(.system(size: 16, weight: .medium)); shortcut("Show / hide assistant", "⌃ ⌥ Space"); shortcut("Move visible assistant", "⌘ + Arrow keys"); shortcut("Ask from conversation", "⌃ ⌥ Return"); shortcut("Start / stop listening", "⌃ ⌥ L"); shortcut("Attach screenshot", "⌃ ⌥ S"); Text("Global shortcuts use macOS hotkey registration and do not require Accessibility access. Escape closes the assistant. Press ⌘, to open AI connections.").font(.system(size: 11)).foregroundStyle(Ink.muted) } }; Card { VStack(alignment: .leading, spacing: 10) { Text("Independent, early software").font(.system(size: 15, weight: .medium)); Text("Model access, recognition language support, and capture exclusion depend on your provider and system. Developer ID signing and Apple notarization are needed before broad distribution.").font(.system(size: 12)).foregroundStyle(Ink.muted).lineSpacing(4) } } }.padding(32) } }
    func shortcut(_ label: String, _ keys: String) -> some View { HStack { Text(label).font(.system(size: 12)); Spacer(); Text(keys).font(.system(size: 12, design: .monospaced)).foregroundStyle(Ink.mint) } }
}
