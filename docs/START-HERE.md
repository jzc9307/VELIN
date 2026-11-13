# Start here

1. Open the current VELIN.app beside the source folder. macOS 14+ and Apple Silicon are required. This is locally ad-hoc signed, not Developer ID notarized.
2. Walk through Setup. Microphone enables your voice; Speech Recognition converts audio to text; Screen & System Audio Recording enables computer audio and requested screenshots. Quit/reopen if macOS requires it. Shortcuts do not need Accessibility access.
3. Try the practice tutorial. It captures/sends nothing and its sample responses are explicitly labeled.
4. Open **AI Connections**, add a slot, choose your provider, choose or type a model, and paste a key. Save, optionally Test, and make it active. There are five slots; multiple slots may use the same provider. Test sends a tiny synthetic question and may incur provider usage charges. No paid service key is included.
5. Open Assistant, type a question, and press Return. Press Listen for live transcription. Use headphones to reduce duplication between microphone and computer audio.
6. Press Screen to attach a screenshot. Review it before asking; × removes it. A vision-capable model is required. Capture targets the main display and excludes VELIN where supported.
7. Session → Notes → Generate notes summarizes the available discussion. History saves locally; Export creates Markdown.

Your data: `~/Library/Application Support/VELIN`. Keys: macOS Keychain service `app.velin.assistant.providers`. The source repository and installer contain neither your keys nor your sessions.

## Five AI slots

OpenAI uses Responses API. Claude uses Messages API. Gemini uses streaming GenerateContent. OpenRouter, Groq, Ollama and Custom use OpenAI-compatible Chat Completions. Custom and local providers must expose that schema. Model names are suggestions, not a guarantee of account access. For Ollama, run/install Ollama separately, pull a model, and use `http://localhost:11434/v1`. A screenshot requires a vision-capable model and endpoint.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Show/hide assistant | Control + Option + Space |
| Ask from current context | Control + Option + Return |
| Listen/stop | Control + Option + L |
| Attach screenshot | Control + Option + S |
| Move visible assistant | Command + arrow keys |
| Hide assistant | Escape |
| AI Connections | Command + comma |

If macOS reports a global hotkey conflict, the menu bar offers the same actions.
