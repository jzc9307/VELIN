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
            let model = profile.model.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "^models/", with: "", options: .regularExpression)
            guard model.range(of: "^[a-zA-Z0-9._-]+$", options: .regularExpression) != nil else { throw VelinError.message("Enter a Gemini model ID, such as gemini-3.5-flash-lite.") }
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

    static func modelListRequest(profile: AIProfile, key: String, pageToken: String? = nil) throws -> URLRequest {
        guard profile.provider == .gemini else { throw VelinError.message("Model refresh is available for Gemini connections.") }
        // Reuse all endpoint and credential validation without sending a generation request.
        var probe = profile; probe.model = "catalog-validation"
        let validated = try request(profile: probe, key: key, system: "", messages: [])
        var components = URLComponents(url: validated.url!, resolvingAgainstBaseURL: false)!
        components.path = String(components.path.dropLast("/models/catalog-validation:streamGenerateContent".count)) + "/models"
        components.queryItems = [URLQueryItem(name: "pageSize", value: "1000")]
        if let pageToken { components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        guard let url = components.url else { throw VelinError.message("The model-list URL is invalid.") }
        var result = URLRequest(url: url, timeoutInterval: 30)
        result.httpMethod = "GET"
        result.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        result.setValue("application/json", forHTTPHeaderField: "Accept")
        return result
    }
    static func models(profile: AIProfile, key: String) async throws -> [String] {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30; config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var token: String?, seenTokens = Set<String>(), result = Set<String>()
        for _ in 0..<10 {
            try Task.checkCancellation()
            let request = try modelListRequest(profile: profile, key: key, pageToken: token)
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw VelinError.message("Invalid model-list response.") }
            guard (200..<300).contains(response.statusCode) else { throw httpError(response.statusCode, request: request, provider: .gemini, body: data) }
            guard data.count <= 2_000_000, let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], let entries = object["models"] as? [[String: Any]] else { throw VelinError.message("Google returned an invalid model catalog.") }
            for entry in entries {
                guard (entry["supportedGenerationMethods"] as? [String])?.contains("generateContent") == true,
                      let name = entry["name"] as? String, name.hasPrefix("models/") else { continue }
                let id = String(name.dropFirst(7))
                if id.count <= 160, id.range(of: "^[a-zA-Z0-9._-]+$", options: .regularExpression) != nil { result.insert(id) }
            }
            guard let next = object["nextPageToken"] as? String, !next.isEmpty else {
                guard !result.isEmpty else { throw VelinError.message("No text-generation models were listed for this connection.") }
                return result.sorted()
            }
            guard seenTokens.insert(next).inserted else { throw VelinError.message("The model catalog repeated a page. Try refreshing again.") }
            token = next
        }
        throw VelinError.message("The model catalog exceeded the page limit. Try refreshing again.")
    }
    static func httpError(_ status: Int, request: URLRequest, provider: Provider, body: Data = Data()) -> VelinError {
        let prefix = "\(provider.rawValue) returned HTTP \(status). "
        var guidance: String
        switch status {
        case 401, 403: guidance = "Check this provider's API key, API permissions, and project access."
        case 404:
            guidance = "The model or API route was not found, or this project cannot access it. Check the model ID and API base URL."
            let model = request.url?.lastPathComponent.components(separatedBy: ":").first ?? ""
            if provider == .gemini, ["gemini-2.5-flash", "gemini-2.5-pro"].contains(model) {
                guidance += " Gemini 2.5 Flash/Pro access is limited to existing users. Choose a current model, save, and test again."
            }
        case 429: guidance = "The provider's quota or rate limit was reached. Check project usage/billing, or wait before retrying."
        case 500...599: guidance = "The provider is having a server problem. Try again shortly."
        default: guidance = "Check the selected model, API endpoint, key, and provider account settings."
        }
        if provider == .gemini, request.url?.host == "generativelanguage.googleapis.com", request.url?.scheme == "https",
           body.count <= 8192, let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            var clean = message.removingPercentEncoding ?? message
            for name in ["x-goog-api-key", "x-api-key", "Authorization"] {
                if let value = request.value(forHTTPHeaderField: name), !value.isEmpty {
                    clean = clean.replacingOccurrences(of: value, with: "[redacted]")
                    if value.hasPrefix("Bearer ") { clean = clean.replacingOccurrences(of: String(value.dropFirst(7)), with: "[redacted]") }
                }
            }
            clean = clean.replacingOccurrences(of: "AIza[A-Za-z0-9_-]+|sk-[A-Za-z0-9_-]+|Bearer [A-Za-z0-9._-]+", with: "[redacted]", options: .regularExpression)
            clean = clean.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
            if !clean.isEmpty { guidance = "Google: \(clean.prefix(500)) \(guidance)" }
        }
        return .message(prefix + guidance)
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
            var body = Data()
            // Only Google's official endpoint can supply a bounded, redacted explanation.
            // Arbitrary/custom servers never get their reflected bodies shown.
            if provider == .gemini, request.url?.host == "generativelanguage.googleapis.com", request.url?.scheme == "https" {
                for try await byte in bytes { body.append(byte); if body.count >= 8192 { break } }
            }
            throw httpError(response.statusCode, request: request, provider: provider, body: body)
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
