import Foundation

@main struct CoreTests {
    static var count = 0
    static func expect(_ condition: @autoclosure () throws -> Bool, _ name: String) throws {
        guard try condition() else { throw VelinError.message("FAIL: \(name)") }; count += 1; print("PASS: \(name)")
    }
    static func object(_ request: URLRequest) throws -> [String: Any] { try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any] }
    @MainActor static func main() async throws {
        var visibility = AssistantVisibilityState()
        let firstShow = visibility.request(visible: true)!
        try expect(visibility.request(visible: true) == nil, "Repeated show does not restart its transition")
        let staleHide = visibility.request(visible: false)!
        let newestShow = visibility.request(visible: true)!
        try expect(!visibility.complete(staleHide) && visibility.targetVisible, "An old hide completion cannot close a newly shown bar")
        try expect(!visibility.complete(firstShow) && visibility.complete(newestShow) && visibility.phase == .visible, "Rapid toggles settle on the latest visible target")
        let lastHide = visibility.request(visible: false)!
        try expect(visibility.complete(lastHide) && visibility.phase == .hidden && !visibility.targetVisible, "Latest hide completes and stays hidden")
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
            var p=AIProfile();p.provider = .custom;p.endpoint=endpoint+"/redirect"
            let request=try AIClient.request(profile:p,key:key,system:"fixture",messages:[ChatMessage(role:"user",text:"Test question")])
            do { try await AIClient.stream(request,provider:.custom) { _ in };throw VelinError.message("Followed redirect") } catch { try expect(error.localizedDescription.contains("HTTP 302"),"Provider redirect rejected") }
        }
        print("\(count) checks passed.")
    }
}
