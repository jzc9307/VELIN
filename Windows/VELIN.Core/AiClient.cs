using System.Net;
using System.Net.Http.Headers;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace Velin.Core;
public sealed record QuickReplies(string Say, string Next, string More) {
    public string Markdown() => "\n\n### Say this\n" + Say + "\n\n### Next step\n" + Next + "\n\n### Explain more\n" + More;
}
public static class ReplyPackage {
    public static readonly string[] Markers = ["[[VELIN_SAY]]", "[[VELIN_NEXT]]", "[[VELIN_MORE]]"];
    public const string Instruction = "Lead with a direct answer in 1-2 short sentences (20-45 words), easy to say aloud. No headings, unsolicited options or long explanation in the first answer. Then prepare hidden optional replies using these exact marker lines in order: [[VELIN_SAY]] one natural response to say aloud, [[VELIN_NEXT]] one next step (30 words), [[VELIN_MORE]] further explanation (100 words). Never invent personal experience or qualifications. Respect an explicit request for longer answers/code.";
    public static (string Answer, QuickReplies? Extras) Parse(string raw, bool final = false) {
        var spans = Markers.Select((m,i) => (Index: raw.IndexOf(m, StringComparison.Ordinal), Id: i)).Where(x => x.Index >= 0).OrderBy(x => x.Index).ToList();
        string Clean(string s) {
            foreach (var marker in Markers) for (var n = Math.Min(marker.Length - 1, s.Length); n > 0; n--) if (s.EndsWith(marker[..n], StringComparison.Ordinal)) { s = s[..^n]; break; }
            return s.Trim();
        }
        if (spans.Count == 0) return (Clean(raw), null);
        string[] extra = ["", "", ""];
        for (var i = 0; i < spans.Count; i++) {
            if (i + 1 == spans.Count && !final) continue;
            var start = spans[i].Index + Markers[spans[i].Id].Length; var end = i + 1 < spans.Count ? spans[i + 1].Index : raw.Length;
            extra[spans[i].Id] = Clean(raw[start..end]);
        }
        return (Clean(raw[..spans[0].Index]), new(extra[0], extra[1], extra[2]));
    }
}
public static class AiClient {
    public static Uri BaseUri(string endpoint) {
        if (!Uri.TryCreate(endpoint.Trim().TrimEnd('/') + "/", UriKind.Absolute, out var uri) || !string.IsNullOrEmpty(uri.UserInfo) || !string.IsNullOrEmpty(uri.Query) || !string.IsNullOrEmpty(uri.Fragment)) throw new ArgumentException("Use an API base URL without credentials, query or fragment.");
        var local = uri.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase) || IPAddress.TryParse(uri.Host, out var ip) && IPAddress.IsLoopback(ip);
        if (uri.Scheme != "https" && !(uri.Scheme == "http" && local)) throw new ArgumentException("HTTPS is required, except for a local model server.");
        return uri;
    }
    public static HttpRequestMessage Request(Profile profile, string key, string system, IReadOnlyList<Message> messages, byte[]? image = null) {
        var endpoint = BaseUri(profile.Endpoint); var model = profile.Model.Trim();
        if (profile.Provider == "Gemini" && model.StartsWith("models/")) model = model[7..];
        if (string.IsNullOrWhiteSpace(model)) throw new ArgumentException("Choose a model ID.");
        if (profile.Provider != "Ollama" && string.IsNullOrWhiteSpace(key)) throw new ArgumentException("Save an API key for this connection.");
        JsonNode body; string route;
        var items = new JsonArray();
        if (profile.Provider == "Gemini") {
            route = "models/" + Uri.EscapeDataString(model) + ":streamGenerateContent?alt=sse";
            for (var i = 0; i < messages.Count; i++) {
                var parts = new JsonArray(new JsonObject { ["text"] = messages[i].Text });
                if (i == messages.Count - 1 && image != null) parts.Add(new JsonObject { ["inlineData"] = new JsonObject { ["mimeType"] = "image/jpeg", ["data"] = Convert.ToBase64String(image) } });
                items.Add(new JsonObject { ["role"] = messages[i].Role == "assistant" ? "model" : "user", ["parts"] = parts });
            }
            body = new JsonObject { ["contents"] = items, ["systemInstruction"] = new JsonObject { ["parts"] = new JsonArray(new JsonObject { ["text"] = system }) } };
        } else if (profile.Provider == "Claude") {
            route = "messages";
            for (var i = 0; i < messages.Count; i++) {
                var content = new JsonArray(new JsonObject { ["type"] = "text", ["text"] = messages[i].Text });
                if (i == messages.Count - 1 && image != null) content.Add(new JsonObject { ["type"] = "image", ["source"] = new JsonObject { ["type"] = "base64", ["media_type"] = "image/jpeg", ["data"] = Convert.ToBase64String(image) } });
                items.Add(new JsonObject { ["role"] = messages[i].Role, ["content"] = content });
            }
            body = new JsonObject { ["model"] = model, ["system"] = system, ["messages"] = items, ["max_tokens"] = 1000, ["stream"] = true };
        } else if (profile.Provider == "OpenAI") {
            route = "responses";
            for (var i = 0; i < messages.Count; i++) {
                var content = new JsonArray(new JsonObject { ["type"] = messages[i].Role == "assistant" ? "output_text" : "input_text", ["text"] = messages[i].Text });
                if (i == messages.Count - 1 && image != null) content.Add(new JsonObject { ["type"] = "input_image", ["image_url"] = "data:image/jpeg;base64," + Convert.ToBase64String(image) });
                items.Add(new JsonObject { ["role"] = messages[i].Role, ["content"] = content });
            }
            body = new JsonObject { ["model"] = model, ["instructions"] = system, ["input"] = items, ["stream"] = true, ["store"] = false };
        } else {
            route = "chat/completions"; items.Add(new JsonObject { ["role"] = "system", ["content"] = system });
            for (var i = 0; i < messages.Count; i++) {
                JsonNode content = JsonValue.Create(messages[i].Text)!;
                if (i == messages.Count - 1 && image != null) content = new JsonArray(new JsonObject { ["type"] = "text", ["text"] = messages[i].Text }, new JsonObject { ["type"] = "image_url", ["image_url"] = new JsonObject { ["url"] = "data:image/jpeg;base64," + Convert.ToBase64String(image) } });
                items.Add(new JsonObject { ["role"] = messages[i].Role, ["content"] = content });
            }
            body = new JsonObject { ["model"] = model, ["messages"] = items, ["stream"] = true };
        }
        var request = new HttpRequestMessage(HttpMethod.Post, new Uri(endpoint, route));
        request.Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json");
        if (profile.Provider == "Gemini") request.Headers.Add("x-goog-api-key", key.Trim());
        else if (profile.Provider == "Claude") { request.Headers.Add("x-api-key", key.Trim()); request.Headers.Add("anthropic-version", "2023-06-01"); }
        else if (key.Length > 0) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", key.Trim());
        return request;
    }
    public static string Delta(JsonNode? node, string provider) {
        if (node?["error"] != null || node?["type"]?.GetValue<string>() is "error" or "response.failed" or "response.incomplete") throw new IOException("The provider could not complete this response. Check model access and available credits.");
        if (provider == "OpenAI") return node?["type"]?.GetValue<string>() == "response.output_text.delta" ? node?["delta"]?.GetValue<string>() ?? "" : "";
        if (provider == "Claude") return node?["delta"]?["text"]?.GetValue<string>() ?? "";
        if (provider == "Gemini") return string.Concat((node?["candidates"]?[0]?["content"]?["parts"] as JsonArray ?? []).Where(p => p?["thought"]?.GetValue<bool>() != true).Select(p => p?["text"]?.GetValue<string>() ?? ""));
        return node?["choices"]?[0]?["delta"]?["content"]?.GetValue<string>() ?? "";
    }
    public static async IAsyncEnumerable<string> Stream(HttpRequestMessage request, string provider, [EnumeratorCancellation] CancellationToken cancellation, HttpMessageHandler? handler = null) {
        using var client = new HttpClient(handler ?? new HttpClientHandler { AllowAutoRedirect = false }, true) { Timeout = Timeout.InfiniteTimeSpan };
        using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellation);
        if (!response.IsSuccessStatusCode) throw new IOException($"Provider returned HTTP {(int)response.StatusCode}. " + ((int)response.StatusCode switch { 401 or 403 => "Check your API key and project access.", 404 => "Check the model ID and API base URL.", 429 => "Quota or rate limit reached.", >= 500 => "Provider is busy; try again later.", _ => "Check this connection." }));
        using var reader = new StreamReader(await response.Content.ReadAsStreamAsync(cancellation));
        var eventData = new StringBuilder();
        while (await reader.ReadLineAsync(cancellation) is { } line) {
            if (line.Length > 1_000_000 || eventData.Length > 2_000_000) throw new IOException("Provider event exceeded the size limit.");
            if (line.StartsWith("data:", StringComparison.Ordinal)) { if (eventData.Length > 0) eventData.Append('\n'); eventData.Append(line[5..].TrimStart()); }
            else if (line.Length == 0 && eventData.Length > 0) {
                var data = eventData.ToString(); eventData.Clear(); if (data == "[DONE]") yield break;
                var delta = Delta(JsonNode.Parse(data), provider); if (delta.Length > 0) yield return delta;
            }
        }
        if (eventData.Length > 0 && eventData.ToString() != "[DONE]") { var delta = Delta(JsonNode.Parse(eventData.ToString()), provider); if (delta.Length > 0) yield return delta; }
    }
}
