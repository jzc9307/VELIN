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
    case general = "General", meeting = "Meeting", interview = "Interview", behavioralInterview = "Behavioral Interview", codingInterview = "Coding Interview", systemDesign = "System Design", caseInterview = "Case Interview", recruiterScreen = "Recruiter Screen", recruiting = "Recruiting", teamMeet = "Team Meet", lecture = "Lecture", coding = "Coding", study = "Study", sales = "Sales", custom = "Custom"
    var id: String { rawValue }
    var icon: String {
        switch self { case .general: return "sparkles"; case .meeting: return "person.2"; case .coding: return "chevron.left.forwardslash.chevron.right"; case .study: return "book"; case .sales: return "chart.line.uptrend.xyaxis"; case .custom: return "slider.horizontal.3"; case .interview: return "graduationcap"; case .behavioralInterview: return "bubble.left.and.bubble.right"; case .codingInterview: return "curlybraces"; case .systemDesign: return "cpu"; case .caseInterview: return "chart.bar.xaxis"; case .recruiterScreen: return "person.crop.rectangle.badge.checkmark"; case .recruiting: return "briefcase"; case .teamMeet: return "video"; case .lecture: return "books.vertical" }
    }
    var instruction: String {
        switch self {
        case .general: return "Give a useful, direct answer. Keep it concise unless more detail is requested."
        case .meeting: return "Help with the current discussion. Lead with a short direct answer that is easy to say aloud. Do not invent commitments or personal experience."
        case .coding: return "Explain the coding problem, propose an approach, and give correct readable code when useful. State assumptions and complexity."
        case .study: return "Teach the concept with clear explanations and small examples. Help the user understand the reasoning."
        case .sales: return "Help understand customer needs and clarify concerns. Suggest concrete follow-up questions without inventing product facts."
        case .interview: return "Help answer the interviewer's actual question concisely, using only the user's supplied background. Never invent qualifications, achievements or experience."
        case .behavioralInterview: return "Help give a natural behavioral interview answer grounded in the user's real background. Use a compact situation/action/result structure when suitable; ask for missing facts instead of inventing them."
        case .codingInterview: return "Help reason through a coding interview: state the approach and key tradeoff concisely. Give correct code and complexity when requested. Do not claim unperformed tests."
        case .systemDesign: return "Help with system design: clarify scale and requirements, then explain a concrete architecture and its main tradeoff. State assumptions; avoid unsupported capacity claims."
        case .caseInterview: return "Structure the case with explicit assumptions, a clear calculation or hypothesis and a concise recommendation. Separate evidence from estimates."
        case .recruiterScreen: return "Help introduce the user's real background and role goals naturally. Use supplied qualifications and experience only; do not invent availability, salary, work authorization or commitments."
        case .recruiting: return "Help structure recruiting discussions and job-related questions. Summarize relevant supplied experience; avoid unsupported personal inferences."
        case .teamMeet: return "Help a team discussion with concise updates, decisions and blockers. Attribute ownership and deadlines only when actually stated."
        case .lecture: return "Explain the lecture concept clearly, preserving the teacher's terminology. Give a short direct answer first and expand only when asked."
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
    var inputSource: String? = nil
}
/// Unanswered computer speech is a draft until the user requests an answer.
/// Speech engines revise partial text and later finalize the same segment.
struct HeardQuestionDraft {
    private var completed: [String] = []
    private var partial = ""
    private var consumedWords = 0
    private var consumedPrefix = ""
    private var editedText: String?
    var isEdited: Bool { editedText != nil }
    var text: String { editedText ?? liveText }
    var liveText: String {
        String((completed + [remainder(partial)]).filter { !$0.isEmpty }.joined(separator: " ").suffix(6000))
    }
    private func clean(_ text: String) -> String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.rangeOfCharacter(from: .alphanumerics) == nil ? "" : value
    }
    private func remainder(_ text: String) -> String {
        if consumedPrefix.unicodeScalars.contains(where: { (0x3400...0x9fff).contains($0.value) }), text.hasPrefix(consumedPrefix) {
            return clean(String(text.dropFirst(consumedPrefix.count)))
        }
        return clean(text.split(whereSeparator: \.isWhitespace).dropFirst(consumedWords).joined(separator: " "))
    }
    mutating func edit(_ words: String) { editedText = String(words.prefix(6000)) }
    mutating func resumeLive() { editedText = nil }
    mutating func update(_ words: String) { partial = clean(words) }
    mutating func finish(_ words: String) {
        let pending = remainder(words)
        if !pending.isEmpty { completed.append(pending) }
        completed = [String(completed.joined(separator: " ").suffix(6000))].filter { !$0.isEmpty }
        partial = ""; consumedWords = 0; consumedPrefix = ""
    }
    mutating func consume() {
        editedText = nil
        completed = []
        consumedWords = partial.split(whereSeparator: \.isWhitespace).count
        consumedPrefix = partial
    }
    mutating func reset() { self = Self() }
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
    var microphone = false
    var systemAudio = true
    var localSpeechOnly = true
    var captureProtection = false
    var overlayOpacity = 0.97
    var onboardingCompleted = false
    var contextFiles: [ContextFile] = []
    var aboutMe = ""
    var modePreferences: [String: ModePreferences] = [:]
    var speechBackend = "apple"
    var localModelPath = ""
    var mixedLanguageHint = "English, Bahasa Melayu, Mandarin Chinese. Preserve the spoken language; do not translate."
    var computerFirstMigrated = false
    enum CodingKeys: String, CodingKey { case profiles, activeProfileID, customInstruction, mode, language, outputLanguage, microphone, systemAudio, localSpeechOnly, captureProtection, overlayOpacity, onboardingCompleted, contextFiles, aboutMe, modePreferences, speechBackend, localModelPath, mixedLanguageHint, computerFirstMigrated }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try c.decodeIfPresent([AIProfile].self, forKey: .profiles) ?? []
        activeProfileID = try c.decodeIfPresent(UUID.self, forKey: .activeProfileID)
        customInstruction = try c.decodeIfPresent(String.self, forKey: .customInstruction) ?? ""
        mode = try c.decodeIfPresent(AssistantMode.self, forKey: .mode) ?? .general
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? "en-US"
        outputLanguage = try c.decodeIfPresent(String.self, forKey: .outputLanguage) ?? "Match the conversation"
        microphone = try c.decodeIfPresent(Bool.self, forKey: .microphone) ?? false
        systemAudio = try c.decodeIfPresent(Bool.self, forKey: .systemAudio) ?? true
        localSpeechOnly = try c.decodeIfPresent(Bool.self, forKey: .localSpeechOnly) ?? true
        captureProtection = try c.decodeIfPresent(Bool.self, forKey: .captureProtection) ?? false
        overlayOpacity = try c.decodeIfPresent(Double.self, forKey: .overlayOpacity) ?? 0.97
        onboardingCompleted = try c.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        contextFiles = try c.decodeIfPresent([ContextFile].self, forKey: .contextFiles) ?? []
        aboutMe = try c.decodeIfPresent(String.self, forKey: .aboutMe) ?? ""
        modePreferences = try c.decodeIfPresent([String: ModePreferences].self, forKey: .modePreferences) ?? [:]
        speechBackend = try c.decodeIfPresent(String.self, forKey: .speechBackend) ?? "apple"
        localModelPath = try c.decodeIfPresent(String.self, forKey: .localModelPath) ?? ""
        mixedLanguageHint = try c.decodeIfPresent(String.self, forKey: .mixedLanguageHint) ?? mixedLanguageHint
        computerFirstMigrated = try c.decodeIfPresent(Bool.self, forKey: .computerFirstMigrated) ?? false
        if modePreferences.isEmpty {
            modePreferences[mode.rawValue] = ModePreferences(instruction: customInstruction, outputLanguage: outputLanguage, files: contextFiles)
        }
    }
    var activeModePreferences: ModePreferences {
        get { modePreferences[mode.rawValue] ?? ModePreferences() }
        set { modePreferences[mode.rawValue] = newValue }
    }
    var selectedInstruction: String { activeModePreferences.instruction }
    var selectedFiles: [ContextFile] { activeModePreferences.files }
    var selectedOutputLanguage: String { activeModePreferences.outputLanguage }
    mutating func migrateComputerFirst() { if !computerFirstMigrated { microphone = false; systemAudio = true; computerFirstMigrated = true } }
}
struct ModePreferences: Codable, Equatable {
    var instruction = ""
    var outputLanguage = "Match the conversation"
    var files: [ContextFile] = []
}
struct AboutMeDraft {
    var name = "", skills = "", qualification = "", experience = "", goals = "", age = ""
    var biography: String {
        var lines: [String] = []
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { lines.append("My name is " + name.trimmingCharacters(in: .whitespacesAndNewlines) + ".") }
        for (label, value) in [("Education / highest qualification", qualification), ("Skills", skills), ("Experience and projects", experience), ("Goals", goals), ("Age (optional)", age)] {
            let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { lines.append(label + ": " + text) }
        }
        return lines.joined(separator: "\n\n")
    }
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
