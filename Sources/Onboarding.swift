import SwiftUI

struct SetupView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        GeometryReader { geometry in HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { VelinMark().frame(width: 30, height: 30); Text("VELIN").font(.system(size: 17, weight: .semibold)).tracking(3) }
                Spacer()
                Text("Less noise.\nMore presence.").font(.system(size: geometry.size.width < 1000 ? 34 : 43, weight: .regular, design: .serif)).tracking(-1.5).lineSpacing(1)
                Text("A thoughtful companion for the conversations that matter.").font(.system(size: 14)).foregroundStyle(Ink.muted).lineSpacing(6).padding(.top, 18)
                SignalArtwork().frame(height: geometry.size.width < 1000 ? 140 : 210).padding(.vertical, 18)
                Spacer()
                HStack(spacing: 7) { ForEach(0..<3) { index in Capsule().fill(index <= model.setupStep ? Ink.mint : .white.opacity(0.12)).frame(width: index == model.setupStep ? 32 : 12, height: 3) } }
                Text("\(min(model.setupStep+1, 3)) OF 3 · MAKE YOURSELF AT HOME").font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(Ink.muted).padding(.top, 15)
            }.padding(28).frame(width: geometry.size.width < 1000 ? 250 : 360).frame(maxHeight: .infinity).background(LinearGradient(colors: [Color(hex: 0x192729), Ink.sidebar, Color(hex: 0x171A26)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Rectangle().fill(Ink.line).frame(width: 1)
            ScrollView { VStack(alignment: .leading, spacing: 24) {
                HStack { Text(["WELCOME", "A LITTLE PERMISSION", "YOUR AI, YOUR CHOICE"][min(model.setupStep, 2)]).font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(Ink.mint); Spacer(); Button("Skip setup") { model.config.onboardingCompleted = true; model.saveConfig(); model.page = "Overview" }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Ink.muted) }
                if model.setupStep == 0 { welcome }
                else if model.setupStep == 1 { permissions }
                else { connections }
            }.padding(28).frame(maxWidth: 660, alignment: .leading) }.frame(maxWidth: .infinity)
        } }.onAppear { model.refreshPermissions() }
    }
    var welcome: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Stay in the moment.\nWe'll hold the context.").font(.system(size: 32, weight: .semibold)).tracking(-1)
            Text("VELIN brings a small, useful layer of AI to your desktop. Built for your Mac, connected to the AI you choose.").font(.system(size: 14)).foregroundStyle(Ink.muted).lineSpacing(5)
            feature("waveform", "Listen without losing your place", "Live text from your microphone and computer audio.")
            feature("viewfinder", "Ask about what's in front of you", "Attach a screenshot, review it, then ask a question.")
            feature("text.alignleft", "Keep the useful parts", "Save your conversation, make notes, and pick up later.")
            HStack { Button("Let's get set up  →") { model.setupStep = 1 }.buttonStyle(Press(primary: true)); Spacer() }.padding(.top, 10)
            Text("No VELIN account or subscription. Your AI provider may charge for usage.").font(.system(size: 10)).foregroundStyle(Ink.muted)
        }
    }
    var permissions: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("You're in control.").font(.system(size: 32, weight: .semibold)).tracking(-1)
            Text("Allow only what you want to use. Listening starts when you press Listen; screenshots happen when you request them.").font(.system(size: 13)).foregroundStyle(Ink.muted).lineSpacing(5)
            PermissionRow(icon: "mic", title: "Hear your voice", detail: "Microphone access for your side of the conversation.", granted: model.microphoneAllowed, action: model.requestMicrophone)
            PermissionRow(icon: "waveform", title: "Turn speech into text", detail: "Apple speech recognition. On-device processing is the default.", granted: model.speechAllowed, action: model.requestSpeech)
            PermissionRow(icon: "display", title: "Bring your screen & audio", detail: "Computer audio during sessions and screenshots when you ask.", granted: model.screenAllowed, action: model.requestScreen)
            Text("If macOS opens System Settings, enable VELIN under Privacy & Security. You may need to quit and reopen after granting screen access. Global shortcuts need no Accessibility permission.").font(.system(size: 11)).foregroundStyle(Ink.muted).lineSpacing(4)
            HStack { Button("← Back") { model.setupStep = 0 }.buttonStyle(Press()); Button("Refresh") { model.refreshPermissions() }.buttonStyle(Press()); Spacer(); Button("Continue →") { model.setupStep = 2 }.buttonStyle(Press(primary: true)) }
        }
    }
    var connections: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Choose your intelligence.").font(.system(size: 32, weight: .semibold)).tracking(-1)
            Text("You'll add your own API keys in AI Connections. Keep up to five provider connections and switch whenever you like.").font(.system(size: 14)).foregroundStyle(Ink.muted).lineSpacing(5)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) { ForEach([Provider.openAI, .claude, .gemini, .openRouter, .groq, .ollama]) { provider in HStack(spacing: 12) { ProviderBadge(provider: provider); Text(provider.rawValue).font(.system(size: 13, weight: .medium)); Spacer() }.padding(15).background(Ink.surface, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Ink.line)) } }
            Card(padding: 18) { HStack(alignment: .top, spacing: 12) { Image(systemName: "lock.shield").foregroundStyle(Ink.mint); Text("Your keys live in macOS Keychain. Your sessions live on this Mac. Questions and attached context go to the provider you select.").font(.system(size: 12)).foregroundStyle(Ink.muted).lineSpacing(4) } }
            HStack { Button("← Back") { model.setupStep = 1 }.buttonStyle(Press()); Spacer(); Button("Take a quick tour →") { model.completeSetup() }.buttonStyle(Press(primary: true)) }
            Button("Set up AI first") { model.config.onboardingCompleted = true; model.saveConfig(); model.page = "AI Connections" }.buttonStyle(.plain).foregroundStyle(Ink.mint).font(.system(size: 12))
        }
    }
    func feature(_ icon: String, _ title: String, _ detail: String) -> some View { HStack(alignment: .top, spacing: 17) { Image(systemName: icon).font(.system(size: 20, weight: .light)).foregroundStyle(Ink.mint).frame(width: 28); VStack(alignment: .leading, spacing: 7) { Text(title).font(.system(size: 14, weight: .medium)); Text(detail).font(.system(size: 12)).foregroundStyle(Ink.muted) } }.padding(.vertical, 8) }
}

struct TutorialView: View {
    @ObservedObject var model: AppModel
    @ViewState var step = 0
    @ViewState var demonstrated = false
    let titles = ["A little help, close at hand.", "Let the conversation flow.", "Bring your screen into focus.", "Keep your workspace comfortable.", "Leave with something useful."]
    let details = ["Open the assistant from the menu bar or with ⌃⌥Space. Type a question, then press Return. ⌃⌥Return asks using your current conversation.", "Press Listen when you're ready. You and Computer appear as separate input sources. Stop at any time; text stays in your session.", "Press Screen or ⌃⌥S to attach a screenshot. Review the preview before sending. You can remove it with the × button.", "Drag the assistant by its top bar. Use ⌃⌥Space to show or hide it and Escape to dismiss it. Capture exclusion is optional and cannot guarantee invisibility.", "Open the Session's Notes tab to generate a summary. Your transcript and notes stay in History. Export a session as Markdown whenever you need it."]
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            HStack { SectionHeading(title: "A minute to feel at home.", subtitle: "An interactive practice tour. No microphone, screenshots, or API calls."); Pill(text: "PRACTICE", color: Ink.lilac) }
            HStack(spacing: 8) { ForEach(0..<5) { i in Button { step = i; demonstrated = false } label: { HStack(spacing: 8) { Text("0\(i+1)").font(.system(size: 10, design: .monospaced)); Text(["Ask", "Listen", "Screen", "Workspace", "Notes"][i]).font(.system(size: 11, weight: .medium)) }.foregroundStyle(step == i ? Ink.background : Ink.muted).padding(.horizontal, 14).padding(.vertical, 10).background(step == i ? Ink.mint : Ink.surface, in: Capsule()) }.buttonStyle(.plain) } }
            Card(padding: 30) { VStack(alignment: .leading, spacing: 24) {
                Text(titles[step]).font(.system(size: 29, weight: .regular, design: .serif)).tracking(-0.5)
                Text(details[step]).font(.system(size: 13)).foregroundStyle(Ink.muted).lineSpacing(6).frame(maxWidth: 640, alignment: .leading)
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Ink.background)
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { VelinMark().frame(width: 22, height: 22); Text("VELIN").font(.system(size: 10, weight: .semibold)).tracking(2); Spacer(); Text("PRACTICE PREVIEW").font(.system(size: 8, weight: .medium)).tracking(1.5).foregroundStyle(Ink.muted) }
                        Divider()
                        if !demonstrated { Text(["What should I ask next?", "Ready when you are.", "A screenshot stays yours until you send it.", "Your assistant, within reach.", "A conversation worth remembering."][step]).font(.system(size: 18, design: .serif)); Text("Try the button below to see what happens.").font(.system(size: 12)).foregroundStyle(Ink.muted) }
                        else { practiceResult }
                        Spacer(minLength: 8)
                        HStack { Label("Screen", systemImage: "viewfinder"); Label(step == 1 && demonstrated ? "Listening" : "Listen", systemImage: "waveform"); Spacer(); Text("General"); Image(systemName: "arrow.up.circle.fill").foregroundStyle(Ink.mint) }.font(.system(size: 11)).foregroundStyle(Ink.muted)
                    }.padding(24)
                }.frame(height: 245).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Ink.line))
                HStack { Button(["Try asking", "Try listening", "Try attaching", "Try hiding", "Try notes"][step]) { demonstrated.toggle() }.buttonStyle(Press(primary: true)); Text("Sample content · no data is captured or sent").font(.system(size: 10)).foregroundStyle(Ink.muted) }
            } }
            HStack { if step > 0 { Button("← Previous") { step -= 1; demonstrated = false }.buttonStyle(Press()) }; Spacer(); if step < 4 { Button("Next →") { step += 1; demonstrated = false }.buttonStyle(Press(primary: true)) } else { Button("Make it yours →") { model.page = model.config.profiles.isEmpty ? "AI Connections" : "Overview" }.buttonStyle(Press(primary: true)) } }
        }.padding(32) }
    }
    @ViewBuilder var practiceResult: some View {
        switch step {
        case 0: VStack(alignment: .leading, spacing: 10) { Text("VELIN · SAMPLE ANSWER").font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(Ink.mint); Text("“What does success look like for the first month?” is a useful next question. It makes expectations concrete.").font(.system(size: 14)).lineSpacing(5) }
        case 1: VStack(alignment: .leading, spacing: 12) { Label("Listening · 00:08", systemImage: "waveform").foregroundStyle(Ink.mint); Text("YOU     Let's agree on the next step."); Text("COMPUTER     I'll share a draft by Friday.") }.font(.system(size: 12))
        case 2: HStack(spacing: 18) { RoundedRectangle(cornerRadius: 8).fill(Ink.lilac.opacity(0.12)).frame(width: 110, height: 75).overlay(Image(systemName: "photo").font(.system(size: 25)).foregroundStyle(Ink.lilac)); VStack(alignment: .leading, spacing: 7) { Text("Screenshot attached").font(.system(size: 14, weight: .medium)); Text("Preview → ask → send").font(.system(size: 12)).foregroundStyle(Ink.muted) } }
        case 3: VStack(spacing: 12) { Image(systemName: "rectangle.dashed").font(.system(size: 34, weight: .ultraLight)).foregroundStyle(Ink.muted); Text("Hidden from your desktop until you summon it again.").font(.system(size: 12)).foregroundStyle(Ink.muted) }.frame(maxWidth: .infinity)
        default: VStack(alignment: .leading, spacing: 9) { Text("SUMMARY").font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(Ink.mint); Text("Draft review agreed for Friday.").font(.system(size: 14)); Text("ACTION ITEM").font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(Ink.lilac); Text("Share the draft · owner not specified · Friday").font(.system(size: 12)).foregroundStyle(Ink.muted) }
        }
    }
}
