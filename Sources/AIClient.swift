import Foundation

enum AIClient {
    static func request(profile: AIProfile, key: String, system: String, messages: [ChatMessage], image: Data? = nil) throws -> URLRequest {
        guard var base = URLComponents(string: profile.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)), let host = base.host, base.user == nil, base.password == nil, base.query == nil, base.fragment == nil,
              base.scheme == "https" || (base.scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host)) else { throw VelinError.message("Use an HTTPS API base URL, or HTTP on localhost for a local model.") }
        guard !profile.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw VelinError.message("Choose a model in AI Connections.") }
        guard !profile.requiresKey || !key.isEmpty else { throw VelinError.message("Paste an API key for this connection in Settings → AI Connections.") }
        base.path = base.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        base.path = "/" + base.path
        if base.path == "/" { base.path = "" }
        var headers = ["Content-Type": "application/json", "Accept": "text/event-stream"]
        let mime = "image/jpeg", encoded = image?.base64EncodedString()
        var body: [String: Any]
        if profile.provider == .openAI {
            base.path += "/responses"
            headers["Authorization"] = "Bearer \(key)"
            let input: [[String: Any]] = messages.enumerated().map { index, message in
                if message.role == "assistant" { return ["role": "assistant", "content": message.text] }
                var content: [[String: Any]] = [["type": "input_text", "text": message.text]]
                if index == messages.count - 1, let encoded { content.append(["type": "input_image", "image_url": "data:\(mime);base64,\(encoded)"]) }
                return ["role": message.role, "content": content]
            }
            body = ["model": profile.model, "instructions": system, "input": input, "stream": true, "store": false, "max_output_tokens": 2048]
        } else if profile.provider == .claude {
            base.path += "/messages"
            headers["x-api-key"] = key; headers["anthropic-version"] = "2023-06-01"
            let input: [[String: Any]] = messages.enumerated().map { index, message in
                var content: [[String: Any]] = [["type": "text", "text": message.text]]
                if index == messages.count - 1, let encoded { content.append(["type": "image", "source": ["type": "base64", "media_type": mime, "data": encoded]]) }
                return ["role": message.role, "content": content]
            }
            body = ["model": profile.model, "system": system, "messages": input, "stream": true, "max_tokens": 2048]
        } else if profile.provider == .gemini {
            let model = profile.model.replacingOccurrences(of: "models/", with: "")
            guard model.range(of: "^[a-zA-Z0-9._-]+$", options: .regularExpression) != nil else { throw VelinError.message("Enter a Gemini model ID, such as gemini-2.5-flash.") }
            base.path += "/models/\(model):streamGenerateContent"; base.queryItems = [URLQueryItem(name: "alt", value: "sse")]
            headers["x-goog-api-key"] = key
            let input: [[String: Any]] = messages.enumerated().map { index, message in
                var parts: [[String: Any]] = [["text": message.text]]
                if index == messages.count - 1, let encoded { parts.append(["inline_data": ["mime_type": mime, "data": encoded]]) }
                return ["role": message.role == "assistant" ? "model" : "user", "parts": parts]
            }
            body = ["contents": input, "system_instruction": ["parts": [["text": system]]], "generationConfig": ["maxOutputTokens": 2048]]
        } else {
            base.path += "/chat/completions"
            if !key.isEmpty { headers["Authorization"] = "Bearer \(key)" }
            var input: [[String: Any]] = [["role": "system", "content": system]]
            input += messages.enumerated().map { index, message in
                if index == messages.count - 1, let encoded { return ["role": message.role, "content": [["type": "text", "text": message.text], ["type": "image_url", "image_url": ["url": "data:\(mime);base64,\(encoded)"]]]] }
                return ["role": message.role, "content": message.text]
            }
            body = ["model": profile.model, "messages": input, "stream": true, "max_tokens": 2048]
        }
        guard let url = base.url else { throw VelinError.message("The API URL is invalid.") }
        var request = URLRequest(url: url, timeoutInterval: 90)
        request.httpMethod = "POST"; request.allHTTPHeaderFields = headers
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func delta(_ json: [String: Any], provider: Provider) throws -> String {
        if let error = json["error"] as? [String: Any] { throw VelinError.message(error["message"] as? String ?? "The provider reported an error.") }
        if json["type"] as? String == "response.incomplete" { throw VelinError.message("The response was incomplete. The partial answer is preserved; ask the model to continue.") }
        if json["type"] as? String == "response.failed" {
            let response = json["response"] as? [String: Any], error = response?["error"] as? [String: Any]
            throw VelinError.message(error?["message"] as? String ?? "The AI response failed.")
        }
        if provider == .openAI { return json["type"] as? String == "response.output_text.delta" ? json["delta"] as? String ?? "" : "" }
        if provider == .claude { return (json["delta"] as? [String: Any])?["text"] as? String ?? "" }
        if provider == .gemini {
            if let feedback = json["promptFeedback"] as? [String: Any], let reason = feedback["blockReason"] as? String { throw VelinError.message("Gemini could not answer: \(reason).") }
            let candidate = (json["candidates"] as? [[String: Any]])?.first
            let content = candidate?["content"] as? [String: Any]
            return (content?["parts"] as? [[String: Any]])?.filter { ($0["thought"] as? Bool) != true }.compactMap { $0["text"] as? String }.joined() ?? ""
        }
        let choice = (json["choices"] as? [[String: Any]])?.first
        return (choice?["delta"] as? [String: Any])?["content"] as? String ?? ""
    }

    static func stream(_ request: URLRequest, provider: Provider, onDelta: @escaping @MainActor (String) -> Void) async throws {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 90; config.timeoutIntervalForResource = 180
        let session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw VelinError.message("Invalid response from the AI provider.") }
        guard (200..<300).contains(response.statusCode) else {
            // Never echo a server body: custom servers may reflect credentials or private prompts.
            throw VelinError.message("Provider returned HTTP \(response.statusCode). Check your model, API key, endpoint, and available credits.")
        }
        var received = false
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8), let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let text = try delta(object, provider: provider)
            if !text.isEmpty { received = true; await onDelta(text) }
        }
        guard received else { throw VelinError.message("The provider returned no text. Check that this model supports streamed text responses.") }
    }
}

private final class NoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
