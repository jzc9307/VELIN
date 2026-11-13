import SwiftUI
import AppKit

struct MainView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Group {
            if model.page == "Setup" { SetupView(model: model) }
            else {
                HStack(spacing: 0) {
                    sidebar.frame(width: 202)
                    VStack(spacing: 0) {
                        HStack {
                            Text(model.page.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1.9).foregroundStyle(Ink.muted)
                            Spacer()
                            if model.recording { Pill(text: "LISTENING · \(clockText(model.elapsed))") }
                            else { Text("YOUR SPACE TO THINK").font(.system(size: 9, weight: .medium)).tracking(1.7).foregroundStyle(Ink.muted.opacity(0.6)) }
                            Button { model.showOverlay() } label: { Label("Assistant", systemImage: "rectangle.topthird.inset.filled") }.buttonStyle(IconPress())
                        }.padding(.horizontal, 30).frame(height: 32)
                        Rectangle().fill(Ink.line).frame(height: 1)
                        content.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }.background(Ink.background)
                        .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 28, bottomLeading: 28)))
                        .overlay(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 28, bottomLeading: 28)).strokeBorder(Ink.line))
                }
            }
        }.background(Ink.sidebar).foregroundStyle(.white.opacity(0.92)).preferredColorScheme(.dark)
            .overlay(alignment: .bottom) {
                if !model.notice.isEmpty {
                    HStack { Text(model.notice).font(.system(size: 12)); Button { model.notice = "" } label: { Image(systemName: "xmark") }.buttonStyle(.plain) }
                        .padding(14).background(Ink.surface, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Ink.mint.opacity(0.2))).padding(22)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let error = model.error {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Color(hex: 0xE6B697))
                        Text(error).font(.system(size: 12)).lineLimit(4).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                        Button { model.error = nil } label: { Image(systemName: "xmark") }.buttonStyle(IconPress()).help("Dismiss error")
                    }.padding(14).frame(width: 420).background(Ink.surface, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Ink.line)).padding(.top, 60).padding(.trailing, 24)
                }
            }
    }
    var sidebar: some View {
        GeometryReader { geometry in ScrollView { VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) { VelinMark().frame(width: 32, height: 32); VStack(alignment: .leading, spacing: 3) { Text("VELIN").font(.system(size: 18, weight: .semibold)).tracking(3); Text("A quieter kind of clarity.").font(.system(size: 10)).foregroundStyle(Ink.muted) } }.padding(.top, 48).padding(.bottom, 22).padding(.horizontal, 18)
            Text("WORKSPACE").font(.system(size: 9, weight: .semibold)).tracking(1.8).foregroundStyle(Ink.muted.opacity(0.6)).padding(.horizontal, 24).padding(.bottom, 10)
            nav("Overview", "square.grid.2x2")
            nav("Session", "waveform")
            nav("History", "clock.arrow.circlepath")
            Text("MAKE IT YOURS").font(.system(size: 9, weight: .semibold)).tracking(1.8).foregroundStyle(Ink.muted.opacity(0.6)).padding(.horizontal, 24).padding(.top, 30).padding(.bottom, 10)
            nav("AI Connections", "circle.hexagongrid")
            nav("Personalization", "slider.horizontal.3")
            nav("Audio & Permissions", "mic")
            nav("Privacy", "hand.raised")
            Spacer(minLength: 16)
            nav("Tutorial", "play.rectangle")
            nav("About", "info.circle")
            HStack(spacing: 9) { Circle().fill(model.activeProfile == nil ? Ink.muted : Ink.mint).frame(width: 6, height: 6); VStack(alignment: .leading, spacing: 4) { Text(model.activeProfile?.provider.rawValue ?? "No AI connected").font(.system(size: 11, weight: .medium)); Text(model.activeProfile?.model ?? "Add your first connection").font(.system(size: 10)).foregroundStyle(Ink.muted).lineLimit(1) } }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 11)).padding(14)
        }.frame(minHeight: geometry.size.height, alignment: .top) }.scrollIndicators(.hidden) }.background(Ink.sidebar)
    }
    func nav(_ name: String, _ icon: String) -> some View {
        Button { model.page = name } label: { HStack(spacing: 11) { Image(systemName: icon).font(.system(size: 14)).frame(width: 18); Text(name).font(.system(size: 12, weight: model.page == name ? .semibold : .regular)).lineLimit(1).minimumScaleFactor(0.85); Spacer(); if model.page == name { Circle().fill(Ink.mint).frame(width: 4, height: 4) } }.foregroundStyle(model.page == name ? Ink.mint : Ink.muted).padding(.horizontal, 13).frame(height: 38).background(model.page == name ? Ink.mint.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 9)).contentShape(Rectangle()) }.buttonStyle(NavigationPress()).padding(.horizontal, 12).padding(.vertical, 2)
    }
    @ViewBuilder var content: some View {
        switch model.page {
        case "Overview": OverviewView(model: model)
        case "Session": SessionView(model: model)
        case "History": HistoryView(model: model)
        case "AI Connections": ConnectionsView(model: model)
        case "Personalization": PreferencesView(model: model)
        case "Audio & Permissions": AudioSettingsView(model: model)
        case "Privacy": PrivacyView(model: model)
        case "Tutorial": TutorialView(model: model)
        default: AboutView()
        }
    }
}

struct OverviewView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        GeometryReader { geometry in ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 22).fill(LinearGradient(colors: [Color(hex: 0x1C292B), Color(hex: 0x191E2B), Ink.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
                    HStack {
                        VStack(alignment: .leading, spacing: 17) {
                            Pill(text: "PERSONAL AI, ON YOUR TERMS")
                            Text("A little clarity.\nRight when you need it.").font(.system(size: geometry.size.width < 800 ? 32 : 39, weight: .regular, design: .serif)).tracking(-1.4).lineSpacing(0).fixedSize(horizontal: false, vertical: true)
                            Text("Stay with the conversation. Let VELIN hold the context.").font(.system(size: 13)).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 12) { Button { model.page = "Session"; model.showOverlay() } label: { Label("Open your assistant", systemImage: "arrow.up.right") }.buttonStyle(Press(primary: true)); Text("⌃ ⌥ Space").font(.system(size: 11, design: .monospaced)).foregroundStyle(Ink.muted) }.padding(.top, 8)
                        }.padding(30)
                        Spacer(minLength: 0)
                        if geometry.size.width >= 800 { SignalArtwork().frame(width: 200, height: 235).padding(.trailing, 26).accessibilityHidden(true) }
                    }
                }.overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.08)))
                HStack { Text("Make room for the moment").font(.system(size: 17, weight: .medium)); Spacer(); Text("THREE WAYS TO BEGIN").font(.system(size: 9, weight: .medium)).tracking(1.5).foregroundStyle(Ink.muted) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
                    action("Listen & stay present", "Live transcript from your mic and computer audio.", "waveform", "Start listening", Ink.mint) { model.page = "Session"; model.startListening() }
                    action("See the bigger picture", "Attach a screenshot and ask about what's on screen.", "viewfinder", "Capture screen", Ink.lilac) { model.capture() }
                    action("Bring your own AI", "Your providers. Your keys. Up to five connections.", "circle.hexagongrid", "AI connections", Color(hex: 0xE6C7A1)) { model.page = "AI Connections" }
                }
                HStack { Text("Recent sessions").font(.system(size: 17, weight: .medium)); Spacer(); Button("View all →") { model.page = "History" }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Ink.mint) }
                if model.sessions.isEmpty {
                    Card { HStack(spacing: 17) { Image(systemName: "text.bubble").font(.system(size: 23, weight: .light)).foregroundStyle(Ink.muted); VStack(alignment: .leading, spacing: 5) { Text("Your next conversation starts here.").font(.system(size: 13, weight: .medium)); Text("Sessions and notes will appear here, saved on this Mac.").font(.system(size: 12)).foregroundStyle(Ink.muted) }; Spacer(); Button("Try the tutorial") { model.startPractice() }.buttonStyle(Press()) } }
                } else { ForEach(model.sessions.prefix(3)) { value in SessionRow(value: value) { model.openSession(value) } } }
                HStack { Image(systemName: "lock.shield"); Text("No VELIN account. No VELIN subscription. AI provider usage is billed separately.") }.font(.system(size: 11)).foregroundStyle(Ink.muted).padding(.top, 4)
            }.padding(24)
        } }
    }
    func action(_ title: String, _ detail: String, _ icon: String, _ button: String, _ color: Color, run: @escaping () -> Void) -> some View {
        Card(padding: 20) { VStack(alignment: .leading, spacing: 13) { Image(systemName: icon).font(.system(size: 21, weight: .light)).foregroundStyle(color).frame(height: 30); Text(title).font(.system(size: 14, weight: .medium)); Text(detail).font(.system(size: 12)).foregroundStyle(Ink.muted).frame(minHeight: 38, alignment: .top).fixedSize(horizontal: false, vertical: true); Button(action: run) { HStack { Text(button); Spacer(); Image(systemName: "arrow.up.right") }.font(.system(size: 11, weight: .semibold)).foregroundStyle(color) }.buttonStyle(.plain).padding(.top, 8) } }
    }
}
struct SignalArtwork: View {
    var body: some View {
        ZStack {
            ForEach(0..<6) { i in Ellipse().stroke(LinearGradient(colors: [Ink.mint.opacity(0.35), Ink.lilac.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1).frame(width: CGFloat(75+i*23), height: CGFloat(100+i*24)).rotationEffect(.degrees(-27)) }
            VelinMark().frame(width: 82, height: 82).shadow(color: Ink.mint.opacity(0.15), radius: 28)
            Circle().fill(Ink.mint).frame(width: 5).offset(x: -82, y: -59)
            Circle().fill(Ink.lilac).frame(width: 4).offset(x: 79, y: 54)
        }
    }
}

struct SessionView: View {
    @ObservedObject var model: AppModel
    @ViewState var tab = "Conversation"
    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) { TextField("Session title", text: $model.session.title).textFieldStyle(.plain).font(.system(size: 24, weight: .semibold)).onSubmit { model.persistSession() }; Text("\(model.session.mode.rawValue) · \(clockText(model.elapsed)) · Saved on this Mac").font(.system(size: 12)).foregroundStyle(Ink.muted) }
                Spacer(); Button("New session") { model.newSession() }.buttonStyle(Press()).disabled(model.recording || model.generating || model.startingAudio)
                Button { model.toggleListening() } label: { Label(model.recording ? "Stop listening" : model.startingAudio ? "Starting…" : "Listen", systemImage: model.recording ? "stop.fill" : "waveform") }.buttonStyle(Press(primary: true)).disabled(model.startingAudio)
            }
            HStack(spacing: 18) { ForEach(["Conversation", "Transcript", "Notes"], id: \.self) { value in Button { tab = value } label: { Text(value).font(.system(size: 12, weight: .semibold)).foregroundStyle(tab == value ? Ink.mint : Ink.muted).padding(.vertical, 9).overlay(alignment: .bottom) { if tab == value { Capsule().fill(Ink.mint).frame(height: 2) } } }.buttonStyle(.plain) }; Spacer(); Button { model.export(model.session) } label: { Label("Export", systemImage: "square.and.arrow.up") }.buttonStyle(Press()) }
            Group {
                if tab == "Conversation" { ChatView(model: model, compact: false) }
                else if tab == "Transcript" {
                    VStack(spacing: 0) {
                        HStack { Label(model.recording ? "Capturing audio" : "Audio is stopped", systemImage: model.recording ? "waveform" : "mic.slash").foregroundStyle(model.recording ? Ink.mint : Ink.muted); Spacer(); Button("Import transcript") { model.importTranscript() }.buttonStyle(Press()) }.font(.system(size: 12)).padding(16)
                        Divider().overlay(Ink.line)
                        if model.session.transcript.isEmpty && model.partials.values.allSatisfy(\.isEmpty) { EmptyState(icon: "waveform", title: "A place for every word", detail: "Press Listen to transcribe, or import a text transcript. Microphone is labeled You; computer audio is labeled Computer.") }
                        else { ScrollView { LazyVStack(alignment: .leading, spacing: 20) { ForEach(model.session.transcript) { line in transcript(line.source, line.text, line.time.formatted(date: .omitted, time: .shortened)) }; ForEach(model.partials.keys.sorted(), id: \.self) { source in if let text = model.partials[source], !text.isEmpty { transcript(source, text, "LIVE") } } }.padding(22).frame(maxWidth: .infinity, alignment: .leading) } }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { Text("Your meeting, distilled.").font(.system(size: 17, weight: .medium)); Spacer(); Button(model.generatingNotes ? "Writing…" : "Generate notes") { model.generateNotes() }.buttonStyle(Press(primary: true)).disabled(model.generating) }
                        Text("Generating sends this session's transcript and conversation to \(model.endpointHost).").font(.system(size: 11)).foregroundStyle(Ink.muted)
                        TextEditor(text: $model.session.notes).font(.system(size: 14)).scrollContentBackground(.hidden).onChange(of: model.session.notes) { _, _ in if !model.generating { model.persistSession() } }
                    }.padding(22)
                }
            }.background(Ink.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Ink.line))
        }.padding(30)
    }
    func transcript(_ source: String, _ text: String, _ time: String) -> some View { VStack(alignment: .leading, spacing: 7) { HStack { Text(source.uppercased()).foregroundStyle(source == "You" ? Ink.mint : Ink.lilac); Text(time).foregroundStyle(Ink.muted) }.font(.system(size: 10, weight: .semibold)).tracking(0.7); Text(text).font(.system(size: 14)).lineSpacing(5).textSelection(.enabled) } }
}

struct ChatView: View {
    @ObservedObject var model: AppModel
    var compact: Bool
    var body: some View {
        VStack(spacing: 0) {
            if model.session.messages.isEmpty {
                VStack(spacing: 15) {
                    VelinMark().frame(width: compact ? 36 : 52, height: compact ? 36 : 52).padding(.bottom, 5)
                    Text("What would help right now?").font(.system(size: compact ? 18 : 23, weight: .regular, design: .serif))
                    Text("Ask a question, bring your screen, or listen to the conversation.").font(.system(size: 12)).foregroundStyle(Ink.muted).multilineTextAlignment(.center)
                    HStack(spacing: 8) {
                        quick("Catch me up", "Summarize the conversation so far.")
                        quick("What should I ask?", "Suggest three useful follow-up questions based on the conversation.")
                    }.padding(.top, 4)
                }.padding(22).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView { LazyVStack(alignment: .leading, spacing: 18) { ForEach(model.session.messages) { message in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text(message.role == "user" ? "YOU" : "VELIN").font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(message.role == "user" ? Ink.muted : Ink.mint); if message.attachment { Image(systemName: "photo").font(.system(size: 10)).foregroundStyle(Ink.lilac) }; Spacer(); if !message.text.isEmpty { Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(message.text, forType: .string); model.notice = "Copied response." } label: { Image(systemName: "doc.on.doc").font(.system(size: 10)).foregroundStyle(Ink.muted) }.buttonStyle(.plain).help("Copy text") } }
                            if message.text.isEmpty && model.generating { HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Thinking with \(model.activeProfile?.provider.rawValue ?? "AI")…").font(.system(size: 12)).foregroundStyle(Ink.muted) } }
                            else { Text(.init(message.text)).font(.system(size: 13)).lineSpacing(5).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                        }.padding(message.role == "user" ? 14 : 2).background(message.role == "user" ? .white.opacity(0.035) : .clear, in: RoundedRectangle(cornerRadius: 12)).id(message.id)
                    }; Color.clear.frame(height: 1).id("bottom") }.padding(compact ? 18 : 24) }
                    .onChange(of: model.session.messages.last?.text) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
            if let image = model.pendingImage, let nsImage = NSImage(data: image) {
                HStack(spacing: 12) { Image(nsImage: nsImage).resizable().scaledToFit().frame(width: 105, height: 65).clipShape(RoundedRectangle(cornerRadius: 7)); VStack(alignment: .leading, spacing: 5) { Text("Screenshot attached").font(.system(size: 12, weight: .medium)); Text("Sent with your next question to \(model.endpointHost).").font(.system(size: 10)).foregroundStyle(Ink.muted) }; Spacer(); Button { model.pendingImage = nil } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).help("Remove screenshot") }.padding(12).background(Ink.lilac.opacity(0.06))
            }
            VStack(spacing: 10) {
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Ask anything…", text: $model.prompt, axis: .vertical).lineLimit(1...4).textFieldStyle(.plain).font(.system(size: 13)).onSubmit { model.ask() }.padding(.vertical, 9)
                    Button { if model.generating { model.cancelAnswer() } else { model.ask() } } label: { Image(systemName: model.generating ? "stop.fill" : "arrow.up").font(.system(size: 13, weight: .bold)).frame(width: 32, height: 32).foregroundStyle(Ink.background).background(Ink.mint, in: RoundedRectangle(cornerRadius: 9)) }.buttonStyle(.plain).help(model.generating ? "Stop response" : "Send question")
                }.padding(.horizontal, 12).padding(.vertical, 6).background(Ink.background, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Ink.line))
                HStack(spacing: 13) {
                    Button { model.capture() } label: { Label("Screen", systemImage: "viewfinder") }.disabled(model.generating)
                    Button { model.toggleListening() } label: { Label(model.recording ? "Stop" : "Listen", systemImage: "waveform").foregroundStyle(model.recording ? Ink.mint : Ink.muted) }.disabled(model.startingAudio)
                    Menu { ForEach(AssistantMode.allCases) { mode in Button(mode.rawValue) { model.config.mode = mode; model.session.mode = mode; model.saveConfig() } } } label: { Label(model.config.mode.rawValue, systemImage: model.config.mode.icon) }.menuStyle(.borderlessButton).fixedSize()
                    Spacer(minLength: 0)
                    if compact { Text("⌃⌥↵").font(.system(size: 10, design: .monospaced)) }
                }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Ink.muted)
                if !compact { Text("Questions send recent conversation and attached context to \(model.endpointHost).").font(.system(size: 10)).foregroundStyle(Ink.muted.opacity(0.75)).frame(maxWidth: .infinity, alignment: .leading) }
            }.padding(compact ? 14 : 18)
        }
    }
    func quick(_ label: String, _ prompt: String) -> some View { Button(label) { model.prompt = prompt }.buttonStyle(Press()).font(.system(size: 11)) }
}

struct SessionRow: View {
    let value: Session
    var open: () -> Void
    var body: some View { Button(action: open) { HStack(spacing: 15) { Image(systemName: value.mode.icon).font(.system(size: 17)).foregroundStyle(Ink.lilac).frame(width: 38, height: 38).background(Ink.lilac.opacity(0.07), in: RoundedRectangle(cornerRadius: 10)); VStack(alignment: .leading, spacing: 6) { Text(value.title).font(.system(size: 13, weight: .medium)).lineLimit(1); Text("\(value.created.formatted(date: .abbreviated, time: .shortened)) · \(value.mode.rawValue)").font(.system(size: 11)).foregroundStyle(Ink.muted) }; Spacer(); Text(clockText(value.duration)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Ink.muted); Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundStyle(Ink.muted) }.padding(16).background(Ink.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Ink.line)) }.buttonStyle(.plain) }
}
struct HistoryView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionHeading(title: "Good conversations stay with you.", subtitle: "Find a thought, revisit a decision, or export your notes.")
            TextField("Search sessions, transcripts, and notes", text: $model.search).velinField()
            if model.filteredSessions.isEmpty { EmptyState(icon: "clock.arrow.circlepath", title: model.search.isEmpty ? "A fresh page" : "No matching sessions", detail: model.search.isEmpty ? "Your saved sessions will appear here after your first conversation." : "Try a different word or phrase.") }
            else { ScrollView { LazyVStack(spacing: 10) { ForEach(model.filteredSessions) { value in SessionRow(value: value) { model.openSession(value) } } } } }
        }.padding(32)
    }
}
