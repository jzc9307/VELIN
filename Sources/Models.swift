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
        case .gemini: return ["gemini-2.5-flash", "gemini-2.5-pro"]
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
        case .meeting: return "Help with the current discussion. Suggest a concise response, useful questions, decisions, and next steps. Don't invent commitments."
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
        "# \(title)\n\n\(created.formatted()) · \(mode.rawValue)\n\n## Notes\n\n\(notes.isEmpty ? "No notes generated." : notes)\n\n## Transcript\n\n" + transcript.map { "[\($0.time.formatted(date: .omitted, time: .shortened))] **\($0.source):** \($0.text)" }.joined(separator: "\n\n") + "\n\n## Conversation\n\n" + messages.map { "**\($0.role == "user" ? "You" : "VELIN"):** \($0.text)" }.joined(separator: "\n\n")
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
