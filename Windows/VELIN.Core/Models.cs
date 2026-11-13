using System.Text.Json;

namespace Velin.Core;
public sealed class Profile {
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = "Personal connection";
    public string Provider { get; set; } = "Gemini";
    public string Endpoint { get; set; } = Providers.Endpoint("Gemini");
    public string Model { get; set; } = "gemini-3.5-flash-lite";
}
public static class Providers {
    public static readonly string[] Names = ["OpenAI", "Claude", "Gemini", "OpenRouter", "Groq", "Ollama", "Custom"];
    public static string Endpoint(string provider) => provider switch {
        "OpenAI" => "https://api.openai.com/v1", "Claude" => "https://api.anthropic.com/v1",
        "Gemini" => "https://generativelanguage.googleapis.com/v1beta", "OpenRouter" => "https://openrouter.ai/api/v1",
        "Groq" => "https://api.groq.com/openai/v1", "Ollama" => "http://localhost:11434/v1", _ => ""
    };
    public static string Model(string provider) => provider switch {
        "OpenAI" => "gpt-4.1-mini", "Claude" => "claude-sonnet-4-5", "Gemini" => "gemini-3.5-flash-lite",
        "Groq" => "llama-3.3-70b-versatile", "OpenRouter" => "openai/gpt-4.1-mini", "Ollama" => "qwen3:8b", _ => ""
    };
}
public sealed class Settings {
    public List<Profile> Profiles { get; set; } = [];
    public Guid? ActiveProfileId { get; set; }
    public string Mode { get; set; } = "Meeting";
    public string Instructions { get; set; } = "";
    public string Language { get; set; } = "en-US";
    public bool Microphone { get; set; } = true;
    public bool ComputerAudio { get; set; } = true;
    public bool CaptureProtection { get; set; }
}
public sealed class Message {
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Role { get; set; } = "user";
    public string Text { get; set; } = "";
    public bool Attachment { get; set; }
    public string? InputSource { get; set; }
    public QuickReplies? Extras { get; set; }
}
public sealed class TranscriptLine {
    public string Source { get; set; } = "Computer";
    public string Text { get; set; } = "";
    public DateTimeOffset Time { get; set; } = DateTimeOffset.Now;
}
public sealed class Session {
    public Guid Id { get; set; } = Guid.NewGuid();
    public DateTimeOffset Created { get; set; } = DateTimeOffset.Now;
    public string Title { get; set; } = "Untitled session";
    public List<Message> Messages { get; set; } = [];
    public List<TranscriptLine> Transcript { get; set; } = [];
    public string Notes { get; set; } = "";
    public string Markdown() => "# " + Title + "\n\n" + string.Join("\n\n", Messages.Select(m => "## " + (m.InputSource == "Computer" ? "Other side" : m.Role) + "\n\n" + m.Text + (m.Extras?.Markdown() ?? ""))) + "\n\n## Transcript\n\n" + string.Join("\n", Transcript.Select(t => $"{t.Source}: {t.Text}")) + "\n\n## Notes\n\n" + Notes;
}
public sealed class HeardDraft {
    string completed = "", partial = ""; int consumedWords; string? edited;
    public bool IsEdited => edited != null;
    public string Text => edited ?? LiveText;
    public string LiveText => Tail(string.Join(" ", new[] { completed, Remaining(partial) }.Where(x => x.Length > 0)), 6000);
    static string Clean(string s) => s.Any(char.IsLetterOrDigit) ? s.Trim() : "";
    static string Tail(string s, int count) => s.Length > count ? s[^count..] : s;
    string Remaining(string text) => Clean(string.Join(" ", text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Skip(consumedWords)));
    public void Update(string words) => partial = Clean(words);
    public void Finish(string words) { completed = Tail((completed + " " + Remaining(words)).Trim(), 6000); partial = ""; consumedWords = 0; }
    public void Edit(string text) => edited = text.Length > 6000 ? text[..6000] : text;
    public void Resume() => edited = null;
    public void Consume() { completed = ""; edited = null; consumedWords = partial.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Length; }
    public void Reset() { completed = partial = ""; consumedWords = 0; edited = null; }
}
public sealed class LocalStore(string root) {
    public string Root { get; } = root;
    static readonly JsonSerializerOptions Json = new() { WriteIndented = true, PropertyNameCaseInsensitive = true };
    public T Load<T>(string name, Func<T> empty) {
        var file = Path.Combine(Root, name);
        if (!File.Exists(file)) return empty();
        return JsonSerializer.Deserialize<T>(File.ReadAllText(file), Json) ?? throw new IOException("Saved data is unreadable; the original file was preserved.");
    }
    public void Save<T>(string name, T value) {
        Directory.CreateDirectory(Root); var file = Path.Combine(Root, name); var tmp = file + "." + Guid.NewGuid() + ".tmp";
        try { File.WriteAllText(tmp, JsonSerializer.Serialize(value, Json)); File.Move(tmp, file, true); }
        finally { if (File.Exists(tmp)) File.Delete(tmp); }
    }
}
