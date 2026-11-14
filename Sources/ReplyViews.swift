import SwiftUI
import AppKit

struct AssistantReplyView: View {
    let message: ChatMessage
    let streaming: Bool
    var embedded = false
    var hideActions = false
    var onlyActions = false
    var selection: Binding<ReplyAction>? = nil
    var onContinue: ((String) -> Void)? = nil
    var continuationDisabled = false
    @ViewState private var localSelected: ReplyAction = .answer
    private var selected: ReplyAction { get { selection?.wrappedValue ?? localSelected } nonmutating set { if let selection { selection.wrappedValue = newValue } else { localSelected = newValue } } }
    var text: String {
        if selected == .answer { return message.quickReplies == nil ? ReplyPackage.brief(message.text) : message.text }
        if selected == .more, message.quickReplies == nil { return message.text }
        return message.quickReplies?[selected] ?? ""
    }
    func available(_ action: ReplyAction) -> Bool {
        if action == .answer { return !message.text.isEmpty }
        if action == .more, message.quickReplies == nil { return !streaming && ReplyPackage.brief(message.text) != message.text }
        return !(message.quickReplies?[action] ?? "").isEmpty
    }
    var body: some View {
        if onlyActions { actions } else { VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(selected == .answer ? "VELIN" : selected.rawValue.uppercased()).font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(Ink.mint)
                if streaming { ProgressView().controlSize(.mini).help("Streaming the answer and preparing optional replies") }
                Spacer()
                if !text.isEmpty {
                    Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) } label: { Label("Copy", systemImage: "doc.on.doc").font(.system(size: 10)) }.buttonStyle(IconPress()).foregroundStyle(Ink.muted).help("Copy the displayed reply")
                }
            }
            if embedded { replyContent }
            else { ScrollView { replyContent }.scrollIndicators(.hidden).defaultScrollAnchor(.top).id(message.id.uuidString + selected.rawValue) }

            if !hideActions { actions }

        }.onChange(of: message.id) { _, _ in selected = .answer }
        }
    }
    var actions: some View {
        ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(ReplyAction.allCases) { action in
                        Button { selected = action } label: { Label(action.rawValue, systemImage: action.icon).lineLimit(1).fixedSize() }
                            .buttonStyle(ReplyPill(selected: selected == action)).disabled(!available(action))
                            .accessibilityValue(selected == action ? "Selected" : available(action) ? "Ready" : streaming ? "Preparing" : "Unavailable")
                            .help("Show this prepared view · no new AI request")
                    }
                    if selected == .next, let onContinue {
                        Button { onContinue(text) } label: { Label("Yes, continue", systemImage: "arrow.turn.down.right").lineLimit(1).fixedSize() }
                            .buttonStyle(ReplyPill(selected: false)).disabled(continuationDisabled || streaming || text.isEmpty)
                            .help("Generate a new reply continuing this view · uses your selected AI")
                    }
                }.padding(.vertical, 2)
            }.scrollIndicators(.hidden).fixedSize(horizontal: false, vertical: true)
    }
    @ViewBuilder var replyContent: some View {
        if text.isEmpty { Text("Thinking…").font(.system(size: 14)).foregroundStyle(Ink.muted).frame(maxWidth: .infinity, alignment: .leading) }
        else { ReplyMarkdown(text: text).frame(maxWidth: .infinity, alignment: .leading) }
    }

}

/// SwiftUI Text handles inline Markdown. Render block boundaries explicitly so
/// headings, list markers and fenced examples never appear as raw ### or ```.
struct ReplyMarkdown: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                if block.code {
                    Text(block.text).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                        .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 11))
                } else {
                    Text(.init(block.text)).font(.system(size: 14, weight: block.heading ? .semibold : .regular))
                        .lineSpacing(4).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    var blocks: [(text: String, code: Bool, heading: Bool)] {
        var result: [(String, Bool, Bool)] = [], lines: [String] = [], code = false
        func flush() { if !lines.isEmpty { result.append((lines.joined(separator: "\n"), code, false)); lines = [] } }
        for line in text.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") { flush(); code.toggle() }
            else if code { lines.append(line) }
            else if line.isEmpty { flush() }
            else if line.hasPrefix("#") { flush(); result.append((line.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression), false, true)) }
            else if line.hasPrefix("* ") || line.hasPrefix("- ") { flush(); result.append(("• " + line.dropFirst(2), false, false)) }
            else { lines.append(line) }
        }
        flush(); return result
    }
}

struct ReplyPill: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: ButtonStyleConfiguration) -> some View { ReplyPillBody(configuration: configuration, selected: selected) }
}
private struct ReplyPillBody: View {
    let configuration: ButtonStyleConfiguration
    let selected: Bool
    @Environment(\.isEnabled) var enabled
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @ViewState private var hovering = false
    var body: some View {
        configuration.label.font(.system(size: 11, weight: .semibold)).padding(.horizontal, 13).padding(.vertical, 9)
            .foregroundStyle(selected ? Ink.background : hovering ? Ink.mint : .white.opacity(0.9))
            .background(selected ? Ink.mint : .white.opacity(configuration.isPressed ? 0.18 : hovering ? 0.12 : 0.06), in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? Ink.mint.opacity(0.5) : hovering ? Ink.mint.opacity(0.4) : .white.opacity(0.12)))
            .opacity(enabled ? 1 : 0.35).contentShape(Capsule()).onHover { hovering = $0 }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovering)
    }
}

/// A single scroll surface retains the session above the newest turn. Only a new
/// user turn changes its anchor; streaming tokens never force the view downward.
struct OverlayConversationView: View {
    @ObservedObject var model: AppModel
    @ViewState private var selected: ReplyAction = .answer
    private var newestQuestion: UUID? { model.session.messages.last(where: { $0.role == "user" })?.id }
    var body: some View {
        VStack(spacing: 0) { GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(model.session.messages) { message in
                            VStack(alignment: .leading, spacing: 12) {
                                if message.role == "user" {
                                    HStack { Spacer(minLength: 32); Text(message.text).font(.system(size: 12, weight: .medium)).textSelection(.enabled).padding(12).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14)) }
                                } else {
                                    AssistantReplyView(message: message, streaming: model.generating && !model.generatingNotes && message.id == model.session.messages.last?.id, embedded: true, hideActions: true, selection: message.id == model.session.messages.last(where: { $0.role == "assistant" })?.id ? $selected : nil)
                                }
                            }.id(message.id)
                        }
                        // Room below a short latest reply lets its question align at top.
                        Color.clear.frame(height: max(24, geometry.size.height - 200))
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                }.scrollIndicators(.hidden).defaultScrollAnchor(.top)
                    .onAppear { if let id = newestQuestion { proxy.scrollTo(id, anchor: .top) } }
                    .onChange(of: newestQuestion) { _, id in if let id { proxy.scrollTo(id, anchor: .top) } }
                    .onChange(of: selected) { _, _ in if let id = newestQuestion { proxy.scrollTo(id, anchor: .top) } }
            }
        }
        if let latest = model.session.messages.last(where: { $0.role == "assistant" }) {
            AssistantReplyView(message: latest, streaming: model.generating && !model.generatingNotes, onlyActions: true, selection: $selected, onContinue: { model.continueReply(messageID: latest.id, displayed: $0) }, continuationDisabled: model.generating).padding(.horizontal, 16).padding(.vertical, 10)
        }
        }.onChange(of: newestQuestion) { _, _ in selected = .answer }
    }
}
