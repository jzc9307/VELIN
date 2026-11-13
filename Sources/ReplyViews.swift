import SwiftUI
import AppKit

struct AssistantReplyView: View {
    let message: ChatMessage
    let streaming: Bool
    @ViewState private var selected: ReplyAction = .answer
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(selected == .answer ? "VELIN" : selected.rawValue.uppercased()).font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(Ink.mint)
                if streaming { ProgressView().controlSize(.mini).help("Streaming the answer and preparing optional replies") }
                Spacer()
                if !text.isEmpty {
                    Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) } label: { Label("Copy", systemImage: "doc.on.doc").font(.system(size: 10)) }.buttonStyle(IconPress()).foregroundStyle(Ink.muted).help("Copy the displayed reply")
                }
            }
            ScrollView {
                if text.isEmpty { Text("Thinking…").font(.system(size: 14)).foregroundStyle(Ink.muted).frame(maxWidth: .infinity, alignment: .leading) }
                else { ReplyMarkdown(text: text).frame(maxWidth: .infinity, alignment: .leading) }
            }.scrollIndicators(.hidden).defaultScrollAnchor(.top).id(message.id.uuidString + selected.rawValue)
            HStack(spacing: 7) {
                ForEach(ReplyAction.allCases) { action in
                    Button { selected = action } label: {
                        Label(action.rawValue, systemImage: action.icon).font(.system(size: 11, weight: .medium))
                            .foregroundStyle(selected == action ? Ink.background : .white.opacity(0.9))
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(selected == action ? Ink.mint : .white.opacity(0.075), in: Capsule())
                            .overlay(Capsule().strokeBorder(selected == action ? Ink.mint.opacity(0.55) : .white.opacity(0.15)))
                    }.buttonStyle(IconPress()).disabled(!available(action))
                        .accessibilityValue(selected == action ? "Selected" : available(action) ? "Ready" : streaming ? "Preparing" : "Unavailable")
                        .help(available(action) ? "Show prepared reply instantly · no new AI request" : streaming ? "Preparing with this answer…" : "Ask a new question to prepare this view")
                }
                Spacer(minLength: 0)
            }.fixedSize(horizontal: false, vertical: true)
        }.onChange(of: message.id) { _, _ in selected = .answer }
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
