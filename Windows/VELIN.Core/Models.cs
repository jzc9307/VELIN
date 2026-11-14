using System.Text.Json;
using System.Text.Json.Serialization;

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
    public bool Microphone { get; set; } = false;
    public bool ComputerAudio { get; set; } = true;
    public bool CaptureProtection { get; set; }
    public string AboutMe { get; set; } = "";
    public Dictionary<string,ModeContext> ModeContexts { get; set; } = [];
    public bool PersonalizationMigrated { get; set; }
    public bool ComputerFirstMigrated { get; set; }
    public string SpeechCountry {get;set;}="MY";
    [JsonIgnore] public string EffectiveSpeechHint=>"Malaysia: English, Bahasa Melayu and Mandarin Chinese; preserve code-switching and the original script. Do not translate. "+MixedLanguageHint;
    [JsonIgnore] public string SpeechDisplayName=>SpeechBackend=="whisper"?"Malaysia · EN / BM / 中文":Language;
    public Settings CaptureSettings(bool mic)=>new(){Microphone=mic,ComputerAudio=!mic,SpeechBackend=SpeechBackend,Language=Language,SpeechCountry=SpeechCountry,LocalModelPath=LocalModelPath,SpeechWorkerPath=SpeechWorkerPath,MixedLanguageHint=MixedLanguageHint};
    public string SpeechBackend { get; set; } = "windows";
    public string LocalModelPath { get; set; } = "";
    public string SpeechWorkerPath { get; set; } = "";
    public string MixedLanguageHint { get; set; } = "English, Bahasa Melayu, Mandarin Chinese. Preserve the spoken language, do not translate.";
    [JsonIgnore] public ModeContext ActiveMode { get { if(!ModeContexts.TryGetValue(Mode,out var value))ModeContexts[Mode]=value=new();return value; } }
    public void Migrate(){if(!PersonalizationMigrated){ModeContexts.TryAdd(Mode,new(){Instructions=Instructions});PersonalizationMigrated=true;}if(!ComputerFirstMigrated){Microphone=false;ComputerAudio=true;ComputerFirstMigrated=true;}}
}
public sealed class ContextFile { public Guid Id {get;set;}=Guid.NewGuid();public string Name {get;set;}="";public string Text {get;set;}=""; }
public sealed class ModeContext { public string Instructions {get;set;}="";public string OutputLanguage {get;set;}="Match the conversation";public List<ContextFile> Files {get;set;}=[]; }
public static class Modes {
    public static readonly string[] Names=["General","Meeting","Interview","Behavioral Interview","Coding Interview","System Design","Case Interview","Recruiter Screen","Recruiting","Team Meet","Lecture","Coding","Study","Sales","Custom"];
    public static string Instruction(string mode)=>mode switch {
        "Interview" or "Recruiter Screen"=>"Answer naturally using only the user's supplied real background; never invent credentials, experience or commitments.",
        "Behavioral Interview"=>"Use the user's real situation, actions and results in a concise answer. Ask for missing facts instead of inventing them.",
        "System Design"=>"Clarify requirements, propose an architecture and explain the main tradeoff. Label assumptions.",
        "Case Interview"=>"Structure the case, separate facts and estimates, then make a concise recommendation.",
        "Coding" or "Coding Interview"=>"Explain the approach and tradeoff. Give code and complexity when requested, without claiming unperformed tests.",
        "Study" or "Lecture"=>"Explain the concept clearly, preserving terminology. Give a direct answer before expanding.",
        _=>"Answer the actual question concisely. Do not invent personal facts, product claims or commitments."
    };
}
public static class Biography {
    public static string Compose(string name,string skills,string qualification,string experience,string goals,string age=""){
        List<string> parts=[];if(!string.IsNullOrWhiteSpace(name))parts.Add("My name is "+name.Trim()+".");
        foreach(var (label,value) in new[]{("Skills",skills),("Education / highest qualification",qualification),("Experience and projects",experience),("Goals",goals),("Age (optional)",age)})if(!string.IsNullOrWhiteSpace(value))parts.Add(label+": "+value.Trim());return string.Join("\n\n",parts);
    }
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
    string completed = "", partial = "", consumedPrefix=""; int consumedWords; string? edited;
    public bool IsEdited => edited != null;
    public string Text => edited ?? LiveText;
    public string LiveText => Tail(string.Join(" ", new[] { completed, Remaining(partial) }.Where(x => x.Length > 0)), 6000);
    static string Clean(string s) => s.Any(char.IsLetterOrDigit) ? s.Trim() : "";
    static string Tail(string s, int count) => s.Length > count ? s[^count..] : s;
    string Remaining(string text) => consumedPrefix.Any(c=>c>=0x3400&&c<=0x9fff)&&text.StartsWith(consumedPrefix,StringComparison.Ordinal)?Clean(text[consumedPrefix.Length..]):Clean(string.Join(" ", text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Skip(consumedWords)));
    public void Update(string words) => partial = Clean(words);
    public void Finish(string words) { completed = Tail((completed + " " + Remaining(words)).Trim(), 6000); partial = ""; consumedWords = 0; consumedPrefix=""; }
    public void Edit(string text) => edited = text.Length > 6000 ? text[..6000] : text;
    public void Resume() => edited = null;
    public void Consume() { consumedPrefix=partial;completed = ""; edited = null; consumedWords = partial.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Length; }
    public void Reset() { completed = partial = consumedPrefix = ""; consumedWords = 0; consumedPrefix=""; edited = null; }
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

public sealed class PromptDictation {
    string basis="",rendered="";readonly HeardDraft speech=new();bool segmentActive,protectEdit;
    public void Begin(string prompt){basis=rendered=prompt;speech.Reset();segmentActive=protectEdit=false;}
    void AcceptEdit(string prompt){if(prompt==rendered)return;basis=rendered=prompt;if(segmentActive)protectEdit=true;}
    string Join(string words)=>words.Length==0?basis:basis+(basis.Length==0||char.IsWhiteSpace(basis[^1])?"":" ")+words;
    public string Update(string words,string current){AcceptEdit(current);if(words.Length==0)return current;speech.Update(words);segmentActive=true;if(protectEdit)return current;return rendered=Join(speech.Text);}
    public string Finish(string words,string current){AcceptEdit(current);speech.Finish(words);if(!protectEdit)basis=Join(speech.Text);rendered=basis;speech.Reset();segmentActive=protectEdit=false;return rendered;}
    public void Consume(){basis=rendered="";speech.Consume();protectEdit=false;}
}
