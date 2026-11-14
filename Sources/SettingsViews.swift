import SwiftUI
import AppKit

struct ConnectionsView: View {
    @ObservedObject var model: AppModel
    @ViewState var selected: UUID?
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    SectionHeading(title: "Your intelligence, connected.", subtitle: "Choose your provider, paste your key, and make it yours. Five slots. One active connection.")
                    Pill(text: "\(model.config.profiles.count) / 5 SLOTS", color: Ink.lilac)
                }
                if geometry.size.width < 800 {
                    HStack(spacing: 12) {
                        Menu {
                            ForEach(model.config.profiles) { profile in
                                Button("\(profile.name) · \(profile.provider.rawValue)") { selected = profile.id; model.connectionResult = "" }
                            }
                        } label: {
                            Label(model.config.profiles.first(where: { $0.id == selected })?.name ?? "Choose connection", systemImage: "circle.hexagongrid")
                        }.menuStyle(.borderlessButton).frame(maxWidth: .infinity, alignment: .leading)
                        Button { model.addProfile(); selected = model.config.profiles.last?.id } label: {
                            Label("Add connection", systemImage: "plus")
                        }.buttonStyle(Press()).disabled(model.config.profiles.count >= 5)
                    }
                    selectedConnection
                } else {
                    HStack(alignment: .top, spacing: 20) {
                        profileList.frame(width: 236)
                        selectedConnection
                    }
                }
            }.padding(24)
        }.onAppear { selected = model.config.activeProfileID ?? model.config.profiles.first?.id }
            .onChange(of: model.config.profiles) { _, profiles in
                if !profiles.contains(where: { $0.id == selected }) { selected = model.config.activeProfileID ?? profiles.first?.id }
            }
    }
    var profileList: some View {
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
        }
    }
    @ViewBuilder var selectedConnection: some View {
        if let id = selected, let profile = model.config.profiles.first(where: { $0.id == id }) { ConnectionEditor(model: model, original: profile).id(id) }
        else { ScrollView { Card { VStack(alignment: .leading, spacing: 20) { VelinMark().frame(width: 44, height: 44); Text("A familiar AI.\nA more personal workspace.").font(.system(size: 27, weight: .regular, design: .serif)); Text("Connect OpenAI, Claude, Gemini, OpenRouter, Groq, or a local model. You can use several keys from the same provider, too.").font(.system(size: 13)).foregroundStyle(Ink.muted).lineSpacing(5); Text("No key is included. Your provider bills its own usage. ChatGPT and Claude subscriptions do not automatically include API credits.").font(.system(size: 11)).foregroundStyle(Ink.muted); Button("Add your first connection") { model.addProfile(); selected = model.config.profiles.last?.id }.buttonStyle(Press(primary: true)).disabled(model.config.profiles.count >= 5) }.frame(maxWidth: .infinity, alignment: .leading) } } }
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
    @ViewState var catalog: [String] = []
    @ViewState var loadingModels = false
    @ViewState var catalogTask: Task<Void, Never>?
    var modelChoices: [String] { catalog.isEmpty ? draft.provider.models : catalog }
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
                    HStack { TextField("Model ID", text: $draft.model).velinField(); if !modelChoices.isEmpty { Menu { ForEach(modelChoices, id: \.self) { value in Button(value) { draft.model = value } } } label: { Text("Models") }.menuStyle(.borderlessButton).fixedSize() } }
                    if draft.provider == .gemini {
                        HStack(alignment: .top) {
                            Text("Refresh Google's catalog, then choose a model. Listed models can still require project access.").font(.system(size: 10)).foregroundStyle(Ink.muted)
                            Spacer(minLength: 10)
                            Button(loadingModels ? "Loading…" : "Refresh models") { refreshModels() }.font(.system(size: 10)).buttonStyle(IconPress()).disabled(loadingModels || model.testingConnection)
                        }
                        if ["gemini-2.5-flash", "gemini-2.5-pro"].contains(draft.model) { Text("This legacy model is limited to projects with prior usage. Try a current Flash model if it returns 404.").font(.system(size: 10)).foregroundStyle(Ink.lilac) }
                    } else { Text("Suggested IDs are editable. Availability depends on your provider account.").font(.system(size: 10)).foregroundStyle(Ink.muted) }
                }
                field("API BASE URL") { TextField("https://your-provider.example/v1", text: $draft.endpoint).velinField(); Text("The destination that receives your requests. HTTPS required except localhost.").font(.system(size: 10)).foregroundStyle(Ink.muted) }
                field(draft.provider == .ollama ? "API KEY · OPTIONAL FOR LOCAL MODELS" : "API KEY") { SecureField(hasSavedKey ? "Key saved · paste here to replace it" : "Paste your API key", text: $key).velinField().privacySensitive(); Text(hasSavedKey ? "A key is saved in Keychain. Leaving this field blank preserves it." : "Stored for this slot in Keychain, never in the project or an .env file.").font(.system(size: 10)).foregroundStyle(Ink.muted) }
                HStack {
                    Button("Save connection") { do { try model.saveProfile(draft, key: key); key = ""; hasSavedKey = SecretStore.contains(original.id); model.connectionResult = ""; localMessage = "Saved securely in Keychain." } catch { localMessage = error.localizedDescription } }.buttonStyle(Press(primary: true))
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
        }.scrollIndicators(.hidden).onAppear { guard !loaded else { return }; hasSavedKey = SecretStore.contains(original.id); loaded = true }
            .onChange(of: draft.provider) { _, provider in guard loaded else { return }; catalogTask?.cancel(); catalog = []; loadingModels = false; draft.endpoint = provider.endpoint; draft.model = provider.models.first ?? ""; key = ""; hasSavedKey = false; localMessage = "Paste a key for \(provider.rawValue)."; model.connectionResult = "" }
            .onChange(of: draft.model) { _, _ in model.connectionResult = ""; localMessage = "" }
            .onChange(of: draft.endpoint) { _, _ in catalogTask?.cancel(); catalog = []; loadingModels = false; model.connectionResult = "" }
            .onDisappear { catalogTask?.cancel() }
            .alert("Remove this connection?", isPresented: $confirmRemove) { Button("Cancel", role: .cancel) {}; Button("Remove", role: .destructive) { model.deleteProfile(original.id) } } message: { Text("Its API key will be removed from Keychain. Your sessions stay saved.") }
    }
    func refreshModels() {
        catalogTask?.cancel()
        let profile = draft
        let credential = key.isEmpty && hasSavedKey ? SecretStore.read(original.id) : key
        loadingModels = true; localMessage = ""
        catalogTask = Task { @MainActor in
            do {
                let values = try await AIClient.models(profile: profile, key: credential)
                guard !Task.isCancelled else { return }
                catalog = values; localMessage = "Loaded \(values.count) catalog models. Choose one, save, and test access."
            } catch {
                guard !Task.isCancelled else { return }
                localMessage = error.localizedDescription
            }
            loadingModels = false
        }
    }
    func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(.system(size: 9, weight: .semibold)).tracking(1.3).foregroundStyle(Ink.muted); content() } }
}

struct PreferencesView: View {
    @ObservedObject var model: AppModel
    @ViewState private var showBiographyBuilder = false
    private var preferences: Binding<ModePreferences> { let key = model.config.mode.rawValue; return Binding(get: { model.config.modePreferences[key] ?? ModePreferences() }, set: { model.config.modePreferences[key] = $0 }) }
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            SectionHeading(title: "Make room for your way of thinking.", subtitle: "Your background stays with you. Each mode keeps its own instructions and files.")
            Card { VStack(alignment: .leading, spacing: 12) {
                HStack { Label("About me", systemImage: "person.crop.circle").font(.system(size: 16, weight: .medium)); Spacer(); Button("Help me write it") { showBiographyBuilder = true }.buttonStyle(Press()) }
                Text("Introduce yourself, your skills, education, real experience and goals. Shared across modes when you ask AI. Age is optional.").font(.system(size: 11)).foregroundStyle(Ink.muted)
                TextEditor(text: $model.config.aboutMe).font(.system(size: 13)).scrollContentBackground(.hidden).frame(height: 130).padding(10).background(Ink.background, in: RoundedRectangle(cornerRadius: 10))
                HStack { Button("Save About me") { model.saveConfig(); model.notice = "About me saved on this Mac." }.buttonStyle(Press(primary: true))
                    if !model.config.selectedInstruction.isEmpty && model.config.aboutMe.isEmpty { Button("Move current instructions here") { model.config.aboutMe = model.config.selectedInstruction; model.config.activeModePreferences.instruction = ""; model.saveConfig() }.buttonStyle(Press()) }
                }
            } }
            Card { VStack(alignment: .leading, spacing: 14) {
                Text("Assistant mode").font(.system(size: 16, weight: .medium))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], spacing: 8) { ForEach(AssistantMode.allCases) { mode in Button { model.config.mode = mode; model.session.mode = mode; model.saveConfig() } label: { Label(mode.rawValue, systemImage: mode.icon).font(.system(size: 12)).frame(maxWidth: .infinity, minHeight: 38).foregroundStyle(model.config.mode == mode ? Ink.mint : Ink.muted) }.buttonStyle(Press(primary: false)) } }
                Text("Built-in behavior").font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.mint)
                Text(model.config.mode.instruction).font(.system(size: 12)).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
                Text(model.config.mode.rawValue + " instructions").font(.system(size: 13, weight: .semibold)).foregroundStyle(Ink.mint)
                Text("Only this mode uses the instructions, response language and files below. Switching modes saves the current edit.").font(.system(size: 11)).foregroundStyle(Ink.muted)
                TextEditor(text: preferences.instruction).id(model.config.mode).font(.system(size: 13)).scrollContentBackground(.hidden).frame(height: 110).padding(10).background(Ink.background, in: RoundedRectangle(cornerRadius: 10))
                TextField("Response language", text: preferences.outputLanguage).velinField()
                Button("Save " + model.config.mode.rawValue + " preferences") { model.saveConfig(); model.notice = "Preferences saved for " + model.config.mode.rawValue + "." }.buttonStyle(Press(primary: true))
            } }
            Card { VStack(alignment: .leading, spacing: 13) {
                HStack { Text("Files for " + model.config.mode.rawValue).font(.system(size: 16, weight: .medium)); Spacer(); Button { model.importContext() } label: { Label("Add files", systemImage: "plus") }.buttonStyle(Press()) }
                Text("Text, Markdown, JSON or text-based PDFs. Up to 20 files per mode, 12,000 characters each. Only this mode’s files are included when you ask.").font(.system(size: 11)).foregroundStyle(Ink.muted)
                if model.config.selectedFiles.isEmpty { Text("No files in this mode yet.").font(.system(size: 12)).foregroundStyle(Ink.muted) }
                ForEach(model.config.selectedFiles) { file in HStack { Image(systemName: "doc.text").foregroundStyle(Ink.lilac); Text(file.name).font(.system(size: 12)); Spacer(); Text("\(file.text.count) chars").font(.system(size: 10)).foregroundStyle(Ink.muted); Button { model.config.activeModePreferences.files.removeAll { $0.id == file.id }; model.saveConfig() } label: { Image(systemName: "xmark") }.buttonStyle(IconPress()).help("Remove from this mode") } }
            } }
        }.padding(28) }.sheet(isPresented: $showBiographyBuilder) { BiographyBuilder(model: model) }
    }
}
struct BiographyBuilder: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @ViewState private var draft = AboutMeDraft()
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("A little about you.").font(.system(size: 25, weight: .semibold)); Spacer(); Button("Cancel") { dismiss() }.buttonStyle(IconPress()) }
            Text("Fill in what you want to share. We’ll turn only these facts into an editable introduction locally—no AI request or invented achievements.").font(.system(size: 12)).foregroundStyle(Ink.muted)
            ScrollView { VStack(spacing: 12) {
                input("Name / preferred name", $draft.name)
                input("Skills", $draft.skills)
                input("Education / highest qualification", $draft.qualification)
                input("Experience, projects and achievements", $draft.experience)
                input("What you’re looking for / goals", $draft.goals)
                input("Age · optional", $draft.age)
                Text(draft.biography.isEmpty ? "Your introduction appears here as you fill this in." : draft.biography).font(.system(size: 12)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(14).background(Ink.background, in: RoundedRectangle(cornerRadius: 10))
            } }
            HStack { Text("Review before saving. About me is shared with your selected AI when you ask.").font(.system(size: 10)).foregroundStyle(Ink.muted); Spacer(); Button(model.config.aboutMe.isEmpty ? "Use introduction" : "Replace About me") { model.config.aboutMe = draft.biography; model.saveConfig(); dismiss() }.buttonStyle(Press(primary: true)).disabled(draft.biography.isEmpty) }
        }.padding(24).frame(width: 560, height: 600).background(Ink.surface).background(HideNativeScrollbars()).foregroundStyle(.white)
    }
    func input(_ title: String, _ text: Binding<String>) -> some View { VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 11)).foregroundStyle(Ink.muted).frame(maxWidth: .infinity, alignment: .leading); TextField(title, text: text).velinField() } }
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
    @ViewState private var speechKey = ""
    @ViewState private var speechKeyResult = ""
    @ObservedObject var model: AppModel
    @ObservedObject private var speechModels = SpeechModels.shared
    private var audioActive: Bool { model.recording || model.startingAudio || model.dictating || model.startingDictation }
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            SectionHeading(title: "Two controls. Two jobs.", subtitle: "Listen follows the computer. Mic types your words into the question box. Use either one, or both independently.")
            Card { VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Image(systemName: "speaker.wave.2").foregroundStyle(Ink.mint).frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) { Text("Listen · computer audio").font(.system(size: 14, weight: .semibold)); Text(model.startingAudio ? "Starting…" : model.recording ? "Listening to your meeting" : "Ready to listen").font(.system(size: 11)).foregroundStyle(Ink.muted) }
                    Spacer(); Button(model.recording ? "Stop Listen" : "Start Listen") { model.toggleListening() }.buttonStyle(Press(primary: model.recording)).disabled(model.startingAudio)
                }
                Divider()
                HStack(spacing: 14) {
                    Image(systemName: "mic").foregroundStyle(Ink.lilac).frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) { Text("Mic · dictate your question").font(.system(size: 14, weight: .semibold)); Text(model.startingDictation ? "Starting…" : model.dictating ? "Typing your speech into the question box" : "Ready to dictate · Listen is not required").font(.system(size: 11)).foregroundStyle(Ink.muted) }
                    Spacer(); Button(model.dictating ? "Stop Mic" : "Start Mic") { model.toggleMicrophone() }.buttonStyle(Press(primary: model.dictating)).disabled(model.startingDictation)
                }
                Text("No chat request is sent automatically. Review or edit the question, then press Enter.").font(.system(size: 11)).foregroundStyle(Ink.muted)
            } }
            if model.showLiveAudio { ListeningStatusView(model: model) }
            Card { VStack(alignment: .leading, spacing: 16) {
                Text("Speech settings").font(.system(size: 16, weight: .medium))
                Picker("Speech engine", selection: $model.config.speechBackend) { Text("Apple · one selected language").tag("apple"); Text("Local multilingual · mixed languages").tag("whisper"); Text("Soniox cloud · mixed languages").tag("soniox") }.pickerStyle(.menu)
                if model.config.speechBackend == "soniox" {
                    Picker("Country", selection: $model.config.speechCountry) { Text("Malaysia · EN / BM / 中文").tag("MY") }.pickerStyle(.menu)
                    Text("Soniox streams speech over the internet and supports English, Malay and Chinese. It uses a separate paid speech API key; your Gemini or other chat key is not used. No model download is needed.").font(.system(size: 12)).foregroundStyle(Ink.muted)
                    SecureField(SecretStore.contains(SonioxProtocol.credentialID) ? "Speech key saved · paste to replace" : "Paste Soniox speech API key", text: $speechKey).velinField()
                    HStack { Button("Save speech key") { do { if !speechKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { try SecretStore.write(speechKey.trimmingCharacters(in: .whitespacesAndNewlines), id: SonioxProtocol.credentialID); speechKey = "" }; speechKeyResult = "Speech key saved in Keychain."; model.saveConfig() } catch { speechKeyResult = error.localizedDescription } }.buttonStyle(Press()); Link("Get Soniox API key ↗", destination: URL(string: "https://console.soniox.com")!) }
                    if !speechKeyResult.isEmpty { Text(speechKeyResult).font(.system(size: 11)).foregroundStyle(Ink.mint) }
                    Toggle("Allow audio streaming to Soniox when I start Listen or Mic", isOn: $model.config.sonioxAudioConsent).toggleStyle(.switch).font(.system(size: 12))
                    Text("Destination: stt-rt.soniox.com · Soniox STT v6. Only the audio control you start is streamed. Stopping it closes its connection. Provider processing, retention and usage charges apply. Nothing starts at launch.").font(.system(size: 11)).foregroundStyle(Ink.muted)
                } else if model.config.speechBackend == "whisper" {
                    Picker("Country", selection: $model.config.speechCountry) { Text("Malaysia").tag("MY") }.pickerStyle(.menu)
                    Label("English + Bahasa Melayu + 中文", systemImage: "globe.asia.australia").font(.system(size: 13, weight: .medium)).foregroundStyle(Ink.mint)
                    Text("Malaysia’s mixed-language preset applies to Listen and Mic. Recognition stays on this device. Mixed sentences can still be wrong; review the words before asking.").font(.system(size: 11)).foregroundStyle(Ink.muted).lineSpacing(3)
                    TextField("Optional names or spelling hints", text: $model.config.mixedLanguageHint).velinField()
                    Text(model.config.localModelPath.isEmpty ? "Choose or download a multilingual model below." : "Selected model: " + URL(fileURLWithPath: model.config.localModelPath).lastPathComponent).font(.system(size: 11)).foregroundStyle(Ink.mint)
                    Text("These are offline speech models, not AI chat providers. Download once, then select an installed model without downloading again.").font(.system(size: 11)).foregroundStyle(Ink.muted)
                    ForEach(SpeechModelOption.all) { option in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) { Text(option.name + " · " + option.size).font(.system(size: 12, weight: .semibold)); Text(option.detail).font(.system(size: 10)).foregroundStyle(Ink.muted) }
                            Spacer()
                            let installed = speechModels.installed.contains(option.id)
                            let selected = installed && model.config.localModelPath == SpeechModels.destination(option).path
                            Button(selected ? "Selected ✓" : installed ? "Use installed" : speechModels.downloadingID == option.id ? "Downloading…" : "Download") {
                                speechModels.fetch(option) { url in model.config.localModelPath = url.path; model.saveConfig() }
                            }.buttonStyle(Press(primary: selected)).disabled(selected || speechModels.downloading || speechModels.checking)
                        }.padding(10).background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 10))
                    }
                    HStack { Button("Choose .bin") { let panel = NSOpenPanel(); panel.allowedContentTypes = [.data]; if panel.runModal() == .OK, let url = panel.url { model.config.localModelPath = url.path; model.saveConfig() } }.buttonStyle(Press()); if speechModels.checking { Text("Checking installed models…").font(.system(size: 10)).foregroundStyle(Ink.muted) } }
                    if speechModels.downloading { HStack { ProgressView(value: speechModels.progress); Button("Cancel download") { speechModels.cancel() }.buttonStyle(IconPress()) } }
                    if !speechModels.result.isEmpty { Text(speechModels.result).font(.system(size: 11)).foregroundStyle(Ink.muted) }
                    Text("One-time model download. Turbo offers a larger multilingual model than Base, at higher memory cost. Malaysian slang and English/Chinese mixing still need your own testing; no accuracy guarantee. Speech arrives in short chunks.").font(.system(size: 10)).foregroundStyle(Ink.muted)
                } else {
                    Picker("Language", selection: $model.config.language) { Text("English (US)").tag("en-US"); Text("English (UK)").tag("en-GB"); Text("English (Malaysia)").tag("en-MY"); Text("中文（普通话）").tag("zh-CN"); Text("中文（繁體）").tag("zh-TW"); Text("Bahasa Melayu (Malaysia)").tag("ms-MY"); Text("粵語（香港）").tag("zh-HK"); Text("Bahasa Indonesia").tag("id-ID"); Text("தமிழ் · Tamil").tag("ta-IN"); Text("日本語").tag("ja-JP"); Text("Español").tag("es-ES"); Text("Français").tag("fr-FR"); Text("Deutsch").tag("de-DE") }.pickerStyle(.menu)
                    Toggle("Keep Apple recognition on this device", isOn: $model.config.localSpeechOnly).toggleStyle(.switch)
                    Text("Turning this off allows Apple’s speech service to process audio. Local language availability depends on installed system assets.").font(.system(size: 11)).foregroundStyle(Ink.muted)
                }
                Button("Save speech settings") { model.saveConfig(); model.notice = "Speech settings saved. Used next time you start Listen or Mic." }.buttonStyle(Press(primary: true))
            } }.disabled(audioActive)
            if audioActive { Text("Stop Listen and Mic to change the speech engine, country or model.").font(.system(size: 11)).foregroundStyle(Ink.mint) }
            permissions
        }.padding(28) }.onAppear { model.refreshPermissions(); speechModels.refresh() }
    }
    var permissions: some View { VStack(spacing: 10) {
        PermissionRow(icon: "mic", title: "Microphone access", detail: "Needed only for Mic dictation into the question box.", granted: model.microphoneAllowed, action: model.requestMicrophone)
        PermissionRow(icon: "waveform.badge.mic", title: "Apple speech recognition", detail: "Needed for the Apple speech engine. Local multilingual uses its own on-device model.", granted: model.speechAllowed, action: model.requestSpeech)
        PermissionRow(icon: "display", title: "Screen & system audio", detail: "Needed for Listen and requested screenshots. Mic dictation works separately.", granted: model.screenAllowed, action: model.requestScreen)
        HStack { Text("macOS may require reopening after a screen permission change.").font(.system(size: 10)).foregroundStyle(Ink.muted); Spacer(); Button("Refresh status") { model.refreshPermissions() }.buttonStyle(IconPress()) }
    } }
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
                Text("Your question, recent conversation, transcript context, custom instructions, and attached documents go to your active chat provider. If you explicitly select and enable Soniox cloud speech, started Listen/Mic audio streams to Soniox separately; offline speech does not upload audio. A screenshot is sent only when attached to that question. Screenshots are not saved to history. Provider processing and retention policies still apply.").font(.system(size: 13)).foregroundStyle(Ink.muted).lineSpacing(5)
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
