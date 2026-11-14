import Foundation
import CoreGraphics

@main struct CoreTests {
    static var count = 0
    static func expect(_ condition: @autoclosure () throws -> Bool, _ name: String) throws {
        guard try condition() else { throw VelinError.message("FAIL: \(name)") }; count += 1; print("PASS: \(name)")
    }
    static func object(_ request: URLRequest) throws -> [String: Any] { try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any] }
    @MainActor static func main() async throws {
        let oldSettings = Data("{\"mode\":\"Meeting\",\"customInstruction\":\"Legacy instructions\",\"contextFiles\":[{\"id\":\"12345678-1234-1234-1234-123456789ABC\",\"name\":\"meeting.txt\",\"text\":\"Meeting context\"}],\"microphone\":true}".utf8)
        var migrated = try JSONDecoder().decode(Configuration.self, from: oldSettings)
        try expect(migrated.selectedInstruction == "Legacy instructions" && migrated.selectedFiles.first?.name == "meeting.txt", "Legacy instructions and files stay with the previously selected mode")
        migrated.mode = .codingInterview
        try expect(migrated.selectedInstruction.isEmpty && migrated.selectedFiles.isEmpty, "Another mode cannot inherit the previous mode's private instructions or files")
        migrated.activeModePreferences = ModePreferences(instruction: "Coding-only fixture", outputLanguage: "English", files: [])
        migrated.mode = .meeting
        try expect(migrated.selectedInstruction == "Legacy instructions", "Switching modes preserves independent saved preferences")
        migrated.aboutMe = "Shared biography fixture"
        let restoredModes = try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(migrated))
        try expect(restoredModes.aboutMe == "Shared biography fixture" && restoredModes.modePreferences[AssistantMode.codingInterview.rawValue]?.instruction == "Coding-only fixture", "About me and mode preferences survive a settings round trip")
        migrated.migrateComputerFirst()
        try expect(!migrated.microphone && migrated.systemAudio, "The one-time computer-first migration turns the microphone off")
        migrated.microphone = true; migrated.migrateComputerFirst()
        try expect(migrated.microphone, "An explicit later microphone choice survives subsequent launches")
        var biography = AboutMeDraft(); biography.name = "Fixture user"; biography.skills = "Swift, Python"; biography.experience = "A supplied project"
        try expect(biography.biography.contains("Swift, Python") && !biography.biography.contains("Age") && !biography.biography.contains("qualification"), "The local biography builder uses only supplied facts and keeps age optional")
        try expect(Set(AssistantMode.allCases.map(\.rawValue)).count == AssistantMode.allCases.count && AssistantMode.allCases.contains(.systemDesign), "New interview, recruiting and lecture modes retain unique saved identities")
        var chineseDraft = HeardQuestionDraft(); chineseDraft.update("你好我是Jason"); chineseDraft.consume(); chineseDraft.update("你好我是Jason我想问一个问题")
        try expect(chineseDraft.text == "我想问一个问题", "Chinese continuation after Enter is not lost to whitespace word counting")
        var visibility = AssistantVisibilityState()
        let firstShow = visibility.request(visible: true)!
        try expect(visibility.request(visible: true) == nil, "Repeated show does not restart its transition")
        let staleHide = visibility.request(visible: false)!
        let newestShow = visibility.request(visible: true)!
        try expect(!visibility.complete(staleHide) && visibility.targetVisible, "An old hide completion cannot close a newly shown bar")
        try expect(!visibility.complete(firstShow) && visibility.complete(newestShow) && visibility.phase == .visible, "Rapid toggles settle on the latest visible target")
        let lastHide = visibility.request(visible: false)!
        try expect(visibility.complete(lastHide) && visibility.phase == .hidden && !visibility.targetVisible, "Latest hide completes and stays hidden")
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let smallPanel = CGRect(x: 300, y: 650, width: 660, height: 120)
        let largerPanel = AssistantPanelGeometry.frame(current: smallPanel, screen: screen, listening: true, expanded: true, image: false, error: false, warning: false)
        try expect(largerPanel.maxY == smallPanel.maxY && largerPanel.width == smallPanel.width, "Opening answer and listening sections preserves the top toolbar position")
        let shortScreen = CGRect(x: -900, y: 0, width: 900, height: 600)
        let constrained = AssistantPanelGeometry.frame(current: smallPanel, screen: shortScreen, listening: true, expanded: true, image: true, error: true, warning: true)
        try expect(shortScreen.insetBy(dx: 16, dy: 16).contains(constrained), "Expanded assistant remains inside a smaller display")
        let sampleReply = "True—the left side of `or` is True.\n[[VELIN_SAY]]\nThe expression is true because `or` short-circuits.\n[[VELIN_NEXT]]\nCheck how parentheses affect the result.\n[[VELIN_MORE]]\nPython evaluates `not`, then `and`, then `or`."
        let packaged = ReplyPackage.parse(sampleReply, final: true)
        try expect(packaged.answer == "True—the left side of `or` is True." && packaged.extras?.say == "The expression is true because `or` short-circuits.", "Optional replies stay outside the concise answer")
        try expect(packaged.extras?.next == "Check how parentheses affect the result." && packaged.extras?.more == "Python evaluates `not`, then `and`, then `or`.", "Next step and explanation are prepared in the same response")
        var partialMarkersHidden = true
        for count in 1..<ReplyPackage.markers[0].count {
            let partial = ReplyPackage.parse("Short answer.\n" + ReplyPackage.markers[0].prefix(count))
            partialMarkersHidden = partialMarkersHidden && partial.answer == "Short answer."
        }
        try expect(partialMarkersHidden, "Every split delimiter is hidden during streaming")
        let preparing = ReplyPackage.parse("Answer.\n[[VELIN_SAY]]\nIncomplete cached response")
        try expect(preparing.answer == "Answer." && preparing.extras?.say == "", "A partially generated action is not offered as ready")
        try expect(ReplyPackage.parse("Answer.\n[[VELIN_SAY]]\nPartial", final: true).extras?.say == "Partial", "Stopping a response preserves useful completed text")
        try expect(ReplyPackage.parse("Plain provider answer.", final: true).answer == "Plain provider answer." && ReplyPackage.parse("Plain provider answer.", final: true).extras == nil, "Unstructured provider replies remain readable")
        var legacyMessage = ChatMessage(role: "assistant", text: "Saved answer")
        let legacyData = try JSONEncoder().encode(legacyMessage)
        try expect(try JSONDecoder().decode(ChatMessage.self, from: legacyData).quickReplies == nil, "Existing history decodes without prepared reply fields")
        legacyMessage.quickReplies = packaged.extras
        let cachedData = try JSONEncoder().encode(legacyMessage)
        try expect(try JSONDecoder().decode(ChatMessage.self, from: cachedData) == legacyMessage, "Prepared actions survive history reload")
        var cachedSession = Session(); cachedSession.messages = [legacyMessage]
        try expect(cachedSession.markdown.contains("### Say this") && cachedSession.markdown.contains("Check how parentheses"), "Export preserves optional reply content")
        try expect(ReplyPackage.brief("Short answer.\n\nLong explanation.") == "Short answer.", "Older verbose replies open on their first paragraph")
        try expect(ReplyPackage.parse("Answer.\n[[VELIN_M", final: true).answer == "Answer.", "Cancellation does not expose a partial delimiter")
        try expect(ReplyPackage.parse("Answer.\n[[VELIN_MORE]]\nDetails.", final: true).extras?.more == "Details.", "A provider omitting earlier optional sections does not leak markers")
        let image = Data([0xFF, 0xD8, 0xFF]), key = "fixture-key-not-a-real-secret"
        for provider in Provider.allCases where provider != .custom {
            var p = AIProfile();p.provider=provider;p.endpoint=provider.endpoint;p.model=provider.models.first!
            let req = try AIClient.request(profile:p,key:key,system:"System",messages:[ChatMessage(role:"user",text:"Test question")],image:image)
            try expect(req.httpMethod=="POST", "\(provider.rawValue) POST")
            let body=try object(req)
            try expect(String(data:req.httpBody!,encoding:.utf8)!.replacingOccurrences(of: "\\/", with: "/").contains(image.base64EncodedString()), "\(provider.rawValue) screenshot encoded")
            if provider == .openAI { try expect(req.url!.path=="/v1/responses" && body["store"] as? Bool == false, "OpenAI stateless Responses request") }
            else if provider == .claude { try expect(req.value(forHTTPHeaderField:"x-api-key")==key && body["system"] as? String == "System", "Claude header and system schema") }
            else if provider == .gemini { try expect(req.url!.query=="alt=sse" && req.value(forHTTPHeaderField:"x-goog-api-key")==key && !req.url!.absoluteString.contains(key), "Gemini key is header-only") }
            else { try expect(req.url!.path.hasSuffix("/chat/completions"), "\(provider.rawValue) compatible endpoint") }
        }
        var gemini = AIProfile(); gemini.provider = .gemini; gemini.endpoint = Provider.gemini.endpoint; gemini.model = " models/gemini-3.5-flash-lite \n"
        let normalized = try AIClient.request(profile: gemini, key: key, system: "", messages: [])
        try expect(normalized.url?.path == "/v1beta/models/gemini-3.5-flash-lite:streamGenerateContent", "Gemini request normalizes model prefix and whitespace")
        let catalogRequest = try AIClient.modelListRequest(profile: gemini, key: key, pageToken: "next page")
        try expect(catalogRequest.httpMethod == "GET" && catalogRequest.url?.path == "/v1beta/models" && catalogRequest.value(forHTTPHeaderField: "x-goog-api-key") == key && !catalogRequest.url!.absoluteString.contains(key), "Model catalog keeps credentials in a header")
        let catalogQuery = URLComponents(url: catalogRequest.url!, resolvingAgainstBaseURL: false)!.queryItems!
        try expect(catalogQuery.contains(URLQueryItem(name: "pageToken", value: "next page")), "Catalog pagination token is encoded as a query item")
        let reflected = try JSONSerialization.data(withJSONObject: ["error": ["message": "Model unavailable. Reflected " + key + " and " + key.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!]])
        let diagnostic = AIClient.httpError(404, request: normalized, provider: .gemini, body: reflected).localizedDescription
        try expect(diagnostic.contains("Model unavailable") && !diagnostic.contains(key) && diagnostic.contains("[redacted]"), "Official Google diagnostics redact reflected credentials")
        var legacy = gemini; legacy.model = "gemini-2.5-flash"
        let legacyRequest = try AIClient.request(profile: legacy, key: key, system: "", messages: [])
        try expect(AIClient.httpError(404, request: legacyRequest, provider: .gemini).localizedDescription.contains("limited to existing users"), "Legacy Gemini 404 explains model access")
        var untrusted = normalized; untrusted.url = URL(string: "https://custom.example/v1beta/models/fixture:streamGenerateContent")!
        try expect(!AIClient.httpError(404, request: untrusted, provider: .gemini, body: reflected).localizedDescription.contains("Reflected"), "Custom endpoint error bodies are never echoed")
        try expect(AIClient.httpError(429, request: normalized, provider: .gemini).localizedDescription.contains("quota"), "Quota errors explain the provider limit")
        let prior = try AIClient.request(profile: AIProfile(), key: key, system: "System", messages: [ChatMessage(role: "user", text: "First"), ChatMessage(role: "assistant", text: "Prior answer"), ChatMessage(role: "user", text: "Continue")])
        let priorBody = try object(prior)
        let priorInput = priorBody["input"] as! [[String: Any]]
        try expect(priorInput[1]["content"] as? String == "Prior answer", "Responses prior assistant uses supported text schema")
        do { _ = try AIClient.delta(["type": "response.incomplete"], provider: .openAI); throw VelinError.message("Swallowed incomplete response") } catch { try expect(error.localizedDescription.contains("incomplete"), "Incomplete Responses stream reports a useful error") }
        for endpoint in ["http://public.example/v1", "https://user:password@example.com/v1", "https://example.com/v1?key=x", "file:///tmp/secret"] {
            var p=AIProfile();p.endpoint=endpoint
            do { _=try AIClient.request(profile:p,key:key,system:"",messages:[]);throw VelinError.message("Accepted unsafe endpoint") } catch { try expect(error.localizedDescription != "Accepted unsafe endpoint", "Reject credential-bearing or insecure endpoint") }
        }
        var local=AIProfile();local.provider = .ollama;local.endpoint="http://127.0.0.1:11434/v1"
        try expect(try AIClient.request(profile:local,key:"",system:"",messages:[]).value(forHTTPHeaderField:"Authorization")==nil,"Local model requires no fake key")
        try expect(try AIClient.delta(["type":"response.output_text.delta","delta":"Hello"],provider:.openAI)=="Hello","Responses stream delta")
        try expect(try AIClient.delta(["delta":["type":"text_delta","text":"Hello"]],provider:.claude)=="Hello","Claude stream delta")
        try expect(try AIClient.delta(["candidates":[["content":["parts":[["text":"hidden","thought":true],["text":"Hello"]]]]]],provider:.gemini)=="Hello","Gemini skips thought content")
        try expect(try AIClient.delta(["choices":[["delta":["content":"Hello"]]]],provider:.custom)=="Hello","Compatible stream delta")
        do { _=try AIClient.delta(["error":["message":"Fixture provider error"]],provider:.openAI);throw VelinError.message("Ignored provider error") } catch { try expect(error.localizedDescription=="Fixture provider error","Provider errors propagate") }
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("velin-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at:root) }
        let store=SessionStore(root:root)
        var config=Configuration();config.profiles=[AIProfile()];config.activeProfileID=config.profiles[0].id
        try store.save(config,name:"settings.json")
        let loaded=try store.load(Configuration.self,name:"settings.json",fallback:Configuration())
        try expect(loaded.activeProfileID==config.activeProfileID,"Configuration round trip retains profile identity")
        let json=try String(contentsOf:root.appendingPathComponent("settings.json"), encoding: .utf8)
        try expect(!json.contains(key) && !json.contains("apiKey"),"Persisted configuration contains no API key field")
        var session=Session();session.title="Fixture session";session.notes="Summary";session.transcript=[TranscriptLine(source:"You",text:"A decision")]
        try store.save([session],name:"sessions.json")
        let sessions=try store.load([Session].self,name:"sessions.json",fallback:[])
        try expect(sessions==[session],"Session persistence round trip")
        try expect(session.markdown.contains("**You:** A decision") && session.markdown.contains("## Notes"),"Markdown export contains transcript and notes")
        try Data("broken-json".utf8).write(to:root.appendingPathComponent("sessions.json"))
        do { _=try store.load([Session].self,name:"sessions.json",fallback:[]);throw VelinError.message("Swallowed corruption") } catch { try expect(error.localizedDescription != "Swallowed corruption","Corrupt history is not silently replaced") }
        if CommandLine.arguments.count>1 {
            let endpoint=CommandLine.arguments[1]
            for provider in [Provider.openAI,.claude,.gemini,.custom] {
                var p=AIProfile();p.provider=provider;p.endpoint=endpoint;p.model="fixture"
                let request=try AIClient.request(profile:p,key:key,system:"fixture",messages:[ChatMessage(role:"user",text:"Test question")])
                var result=""
                try await AIClient.stream(request,provider:provider) { result += $0 }
                try expect(result=="Hello world","\(provider.rawValue) full SSE transport")
            }
            var catalogProfile = gemini; catalogProfile.endpoint = endpoint
            let models = try await AIClient.models(profile: catalogProfile, key: key)
            try expect(models == ["fixture-flash", "fixture-pro"], "Model catalog paginates, deduplicates and excludes unsupported IDs")
            catalogProfile.endpoint = endpoint + "/catalog-loop"
            do { _ = try await AIClient.models(profile: catalogProfile, key: key); throw VelinError.message("Accepted repeated catalog page") } catch { try expect(error.localizedDescription.contains("repeated a page"), "Catalog rejects repeated pagination tokens") }
            catalogProfile.endpoint = endpoint + "/catalog-redirect"
            do { _ = try await AIClient.models(profile: catalogProfile, key: key); throw VelinError.message("Followed catalog redirect") } catch { try expect(error.localizedDescription.contains("HTTP 302"), "Catalog redirects cannot forward credentials") }
            catalogProfile.endpoint = endpoint + "/http404"; catalogProfile.model = "fixture"
            let failedRequest = try AIClient.request(profile: catalogProfile, key: key, system: "", messages: [])
            do { try await AIClient.stream(failedRequest, provider: .gemini) { _ in }; throw VelinError.message("Accepted HTTP 404") } catch { try expect(error.localizedDescription.contains("HTTP 404") && !error.localizedDescription.contains(key), "HTTP failures preserve status without reflecting custom-server credentials") }
            var p=AIProfile();p.provider = .custom;p.endpoint=endpoint+"/redirect"
            let request=try AIClient.request(profile:p,key:key,system:"fixture",messages:[ChatMessage(role:"user",text:"Test question")])
            do { try await AIClient.stream(request,provider:.custom) { _ in };throw VelinError.message("Followed redirect") } catch { try expect(error.localizedDescription.contains("HTTP 302"),"Provider redirect rejected") }
        }
        print("\(count) checks passed.")
    }
}
