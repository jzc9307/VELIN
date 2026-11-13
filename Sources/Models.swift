import Foundation

enum Provider: String, Codable, CaseIterable, Identifiable {
    case openAI = "OpenAI", claude = "Claude", gemini = "Gemini", openRouter = "OpenRouter", groq = "Groq", ollama = "Ollama", custom = "Custom"
    var id: String { rawValue }
    var endpoint: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .claude: return "https://api.anthropic.com/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .ollama: return "http://localhost:11434/v1"
        case .custom: return ""
        }
    }
    var models: [String] {
        switch self {
        case .openAI: return ["gpt-4.1-mini", "gpt-4.1", "gpt-4o"]
        case .claude: return ["claude-sonnet-4-5", "claude-haiku-4-5"]
        case .gemini: return ["gemini-3.5-flash-lite", "gemini-3.8-flash", "gemini-2.5-flash-lite"]
        case .openRouter: return ["openai/gpt-4.1-mini", "anthropic/claude-sonnet-4.5"]
        case .groq: return ["llama-3.3-70b-versatile", "openai/gpt-oss-120b"]
        case .ollama: return ["qwen3:8b", "gemma3:4b"]
        case .custom: return []
        }
    }
}

struct AIProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = "Personal connection"
    var provider: Provider = .openAI
    var endpoint = Provider.openAI.endpoint
    var model = "gpt-4.1-mini"
    // Secrets deliberately never enter Codable configuration.
    var requiresKey: Bool { provider != .ollama }
}

enum AssistantMode: String, Codable, CaseIterable, Identifiable {
    case general = "General", meeting = "Meeting", coding = "Coding", study = "Study", sales = "Sales", custom = "Custom"
    var id: String { rawValue }
    var icon: String {
        switch self { case .general: return "sparkles"; case .meeting: return "person.2"; case .coding: return "chevron.left.forwardslash.chevron.right"; case .study: return "book"; case .sales: return "chart.line.uptrend.xyaxis"; case .custom: return "slider.horizontal.3" }
    }
    var instruction: String {
        switch self {
        case .general: return "Give a useful, direct answer. Keep it concise unless more detail is requested."
        case .meeting: return "Help with the current discussion. Lead with a short direct answer that is easy to say aloud. Do not invent commitments or personal experience."
        case .coding: return "Explain the coding problem, propose an approach, and give correct readable code when useful. State assumptions and complexity."
        case .study: return "Teach the concept with clear explanations and small examples. Help the user understand the reasoning."
        case .sales: return "Help understand customer needs and clarify concerns. Suggest concrete follow-up questions without inventing product facts."
        case .custom: return "Follow the user's custom instructions."
        }
    }
}

struct TranscriptLine: Codable, Identifiable, Equatable {
    var id = UUID()
    var time = Date()
    var source: String
    var text: String
}
struct ChatMessage: Codable, Identifiable, Equatable {
    var id = UUID()
    var role: String
    var text: String
    var time = Date()
    var attachment: Bool = false
    var quickReplies: QuickReplies? = nil
}
enum ReplyAction: String, CaseIterable, Identifiable {
    case answer = "Answer", say = "Say this", next = "Next step", more = "Explain more"
    var id: String { rawValue }
    var icon: String {
        switch self { case .answer: return "text.bubble"; case .say: return "quote.bubble"; case .next: return "arrow.turn.down.right"; case .more: return "sparkles" }
    }
}
struct QuickReplies: Codable, Equatable {
    var say = ""
    var next = ""
    var more = ""
    subscript(_ action: ReplyAction) -> String {
        switch action { case .answer: return ""; case .say: return say; case .next: return next; case .more: return more }
    }
    var markdown: String {
        [("Say this", say), ("Next step", next), ("Explain more", more)].filter { !$0.1.isEmpty }.map { "### \($0.0)\n\n\($0.1)" }.joined(separator: "\n\n")
    }
}
/// A single answer-first stream also prepares optional views. No follow-up call is
/// made when a ready chip is selected. Partial delimiters never flash in the UI.
struct ReplyPackage {
    static let markers = ["[[VELIN_SAY]]", "[[VELIN_NEXT]]", "[[VELIN_MORE]]"]
    static let instruction = """
    RESPONSE PRESENTATION:
    Start with the direct answer only: 1-2 short sentences, about 20-45 words, easy to read during a conversation. Do not add headings, options, next steps, or an unsolicited example to this first answer. If the user explicitly requests a longer answer or code, satisfy that request instead.
    After the answer, prepare three optional views in this exact order, separated by the exact marker lines below. These views are hidden behind buttons, so never announce them in the answer. Do not wrap the entire response in a code fence or use JSON.
    [[VELIN_SAY]]
    One natural 1-2 sentence response the user could say aloud, based only on supplied facts. Never invent their experience, credentials, or commitments. No label or preamble.
    [[VELIN_NEXT]]
    One useful next action or question, at most 30 words. No label or preamble.
    [[VELIN_MORE]]
    A little more explanation, at most 100 words, with one small example only when useful. Markdown is allowed here. No redundant section title. Stop after this section.
    """
    var answer: String
    var extras: QuickReplies?
    static func parse(_ raw: String, final: Bool = false) -> ReplyPackage {
        var spans: [(Int, Range<String.Index>)] = []
        for (i, marker) in markers.enumerated() {
            if let range = raw.range(of: marker) { spans.append((i, range)) }
        }
        spans.sort { $0.1.lowerBound < $1.1.lowerBound }
        func clean(_ text: Substring) -> String {
            var value = String(text)
            do {
                for marker in markers {
                    for count in stride(from: min(marker.count - 1, value.count), through: 1, by: -1) {
                        if value.hasSuffix(String(marker.prefix(count))) { value = String(value.dropLast(count)); break }
                    }
                }
            }
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let first = spans.first else { return ReplyPackage(answer: clean(raw[...]), extras: nil) }
        var extras = QuickReplies()
        for (position, span) in spans.enumerated() {
            let complete = position + 1 < spans.count || final
            guard complete else { continue }
            let end = position + 1 < spans.count ? spans[position + 1].1.lowerBound : raw.endIndex
            let text = clean(raw[span.1.upperBound..<end])
            switch span.0 { case 0: extras.say = text; case 1: extras.next = text; default: extras.more = text }
        }
        return ReplyPackage(answer: clean(raw[..<first.1.lowerBound]), extras: extras)
    }
    static func brief(_ text: String) -> String {
        let first = text.components(separatedBy: "\n\n").first ?? text
        guard first.count > 420 else { return first }
        let prefix = String(first.prefix(420))
        return (prefix.lastIndex(of: " ").map { String(prefix[..<$0]) } ?? prefix) + "…"
    }
}
struct Session: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String = "Untitled session"
    var created = Date()
    var mode: AssistantMode = .general
    var transcript: [TranscriptLine] = []
    var messages: [ChatMessage] = []
    var notes: String = ""
    var duration: Double = 0
    var searchableText: String { ([title, notes] + transcript.map(\.text) + messages.map(\.text)).joined(separator: " ") }
    var markdown: String {
        "# \(title)\n\n\(created.formatted()) · \(mode.rawValue)\n\n## Notes\n\n\(notes.isEmpty ? "No notes generated." : notes)\n\n## Transcript\n\n" + transcript.map { "[\($0.time.formatted(date: .omitted, time: .shortened))] **\($0.source):** \($0.text)" }.joined(separator: "\n\n") + "\n\n## Conversation\n\n" + messages.map { "**\($0.role == "user" ? "You" : "VELIN"):** \($0.text)" + ($0.quickReplies.map { "\n\n" + $0.markdown } ?? "") }.joined(separator: "\n\n")
    }
}
struct ContextFile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var text: String
}
struct Configuration: Codable {
    var profiles: [AIProfile] = []
    var activeProfileID: UUID?
    var customInstruction = ""
    var mode: AssistantMode = .general
    var language = "en-US"
    var outputLanguage = "Match the conversation"
    var microphone = true
    var systemAudio = true
    var localSpeechOnly = true
    var captureProtection = false
    var overlayOpacity = 0.97
    var onboardingCompleted = false
    var contextFiles: [ContextFile] = []
}

enum VelinError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): return text } }
}

struct SessionStore {
    let root: URL
    init(root: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("VELIN")) { self.root = root }
    func load<T: Decodable>(_ type: T.Type, name: String, fallback: T) throws -> T {
        let url = root.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return fallback }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
    func save<T: Encodable>(_ value: T, name: String) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let url = root.appendingPathComponent(name)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
