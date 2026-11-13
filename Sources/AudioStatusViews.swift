import SwiftUI

struct ListeningStatusView: View {
    @ObservedObject var model: AppModel
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(model.startingAudio ? "Connecting audio…" : model.recording ? "Listening · " + model.config.language : "Audio is stopped", systemImage: "waveform").font(.system(size: 10, weight: .semibold)).foregroundStyle(Ink.mint)
                Spacer()
                if compact && !model.pendingHeardQuestion.isEmpty {
                    Button(model.generating ? "Answering…" : "Answer ↵") { model.ask() }.buttonStyle(Press(primary: true)).font(.system(size: 10, weight: .semibold)).disabled(model.generating).keyboardShortcut(.return, modifiers: [])
                }
                if compact { Button("Transcript ↗") { model.sessionTab = "Transcript"; model.page = "Session"; model.openMain() }.font(.system(size: 10)).buttonStyle(IconPress()) }
            }.frame(height: compact ? 36 : nil)
            HStack(spacing: 16) {
                meter("You", "mic", model.level)
                meter("Computer", "speaker.wave.2", model.computerLevel)
            }
            if !compact { Text("Microphone input: " + model.microphoneInputName + ". Teams may use a different input.").font(.system(size: 10)).foregroundStyle(Ink.muted) }
            if !model.audioWarning.isEmpty { Text(model.audioWarning).font(.system(size: 10)).foregroundStyle(Ink.lilac).lineLimit(compact ? 2 : 6) }
            Text(!model.pendingHeardQuestion.isEmpty ? "Other side: " + model.pendingHeardQuestion : model.liveTranscriptPreview.isEmpty ? (model.recording && model.elapsed >= 8 ? "No words yet. Check the call audio, input meters, and transcription language." : "Live words appear here as you or the meeting speaks.") : model.liveTranscriptPreview)
                .font(.system(size: compact ? 11 : 13)).foregroundStyle(model.liveTranscriptPreview.isEmpty ? Ink.muted : .white.opacity(0.95)).lineLimit(compact ? 2 : 5).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(compact ? 13 : 18).background(Ink.background.opacity(model.config.overlayOpacity))
    }
    func meter(_ source: String, _ icon: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) { Image(systemName: icon); Text(source); Spacer(); Text(model.audioInputStates[source] ?? "Stopped").lineLimit(1).minimumScaleFactor(0.8) }.font(.system(size: 9)).foregroundStyle(Ink.muted)
            GeometryReader { geometry in
                ZStack(alignment: .leading) { Capsule().fill(.white.opacity(0.08)); Capsule().fill(Ink.mint).frame(width: max(0, min(1, value)) * geometry.size.width) }
            }.frame(height: 3).accessibilityLabel(source + " audio level").accessibilityValue(String(Int(value * 100)) + "%")
        }.frame(maxWidth: .infinity)
    }
}

struct HeardQuestionView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        if !model.pendingHeardQuestion.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("OTHER SIDE", systemImage: "waveform").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(Ink.mint)
                    Spacer()
                    Button(model.generating ? "Answering…" : "Answer ↵") { model.ask() }.buttonStyle(Press(primary: true)).font(.system(size: 11, weight: .semibold)).disabled(model.generating).keyboardShortcut(.return, modifiers: [])
                }
                Text(model.pendingHeardQuestion).font(.system(size: 13)).lineSpacing(4).lineLimit(4).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                Text("Press Enter to answer · ⌃⌥Return from another app").font(.system(size: 10)).foregroundStyle(Ink.muted)
            }.padding(16).background(Ink.mint.opacity(0.06), in: RoundedRectangle(cornerRadius: 14)).padding(12)
        }
    }
}
