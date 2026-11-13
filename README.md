<p align="center"><img src="docs/assets/readme-banner.svg" alt="VELIN — A quieter kind of clarity" width="100%"></p>

<p align="center"><strong>A native personal AI workspace for your Mac.</strong><br>Live transcription · Screenshot questions · Meeting notes · Five secure AI connections</p>

<p align="center">SwiftUI + AppKit · macOS 14+ · Apple Silicon · Bring your own key · MIT</p>

VELIN keeps useful help within reach while you stay with the conversation. Open a slim floating assistant bar, listen when you choose, ask about your screen, and leave with notes you can actually use. No VELIN account or subscription is required. Your AI provider bills its own usage.

## What it does

- **Five AI slots:** OpenAI, Claude, Gemini, OpenRouter, Groq, Ollama and custom compatible endpoints. Pick a model, paste a key, save it in Keychain, and choose your active connection. Multiple slots may use the same provider.
- **A native assistant:** movable floating bar with an expandable response, menu-bar controls, global keyboard shortcuts, original mint/lilac interface and VELIN emblem.
- **Live text:** microphone and computer audio transcribed separately through Apple Speech, requiring on-device recognition by default. Audio files are not retained.
- **Screen context:** requested screenshots are previewed before sending to a vision-capable model and are not saved to session history.
- **Personal context:** General, Meeting, Coding, Study, Sales and Custom modes, custom instructions, and text/PDF context files.
- **A useful record:** searchable local session history, editable AI-generated notes, transcript import and Markdown export.
- **A gentle start:** permission setup plus an interactive five-step practice tutorial that sends/captures nothing.

## Start

Open the current **VELIN.app** in the outer workspace folder. Follow [Start here](docs/START-HERE.md), add a connection under **AI Connections**, and open the assistant. The [user guide](docs/USER-GUIDE.md) explains data flow, audio, models and troubleshooting.

| Action | Shortcut |
| --- | --- |
| Show / hide assistant | Control + Option + Space |
| Ask from current context | Control + Option + Return |
| Start / stop listening | Control + Option + L |
| Attach screenshot | Control + Option + S |
| Move visible assistant | Command + arrow keys |
| Hide assistant | Escape |

## Build from source

Requires an Apple Silicon Mac with macOS 14+, Apple's Command Line Tools (or Xcode), and Python 3. No npm packages, API secrets, or downloaded model weights are needed to compile.

```bash
xcode-select --install  # only if the Apple developer tools are missing
bash scripts/test.sh
bash scripts/build.sh
```

A fresh clone creates `dist/VELIN.app`. In the local workspace, the `.velin-workspace` marker keeps the current app beside this source folder and caches in the outer `work/` folder. Quit VELIN before replacing its bundle. Use the included VS Code build/test/release tasks. The icon can be regenerated with `python3 scripts/make-icon.py`.

## Privacy and practical limits

Keys are stored in macOS Keychain. Session/configuration text is written atomically to `~/Library/Application Support/VELIN`, with owner-only filesystem permissions. It is not separately encrypted by VELIN. The repository's `.env.example` is a blank reference only; the app never stores keys there.

When you ask a question or generate notes, relevant transcript, chat, instructions and attached context go to the selected provider. Screenshots are sent only when attached. Provider processing, credits, model access and retention still apply; a consumer chat subscription is separate from API access. Unsupported on-device speech languages fail visibly rather than silently switching to cloud processing.

**Capture exclusion is best effort, not guaranteed invisibility.** VELIN requests the legacy NSWindow sharing hint only when enabled. Modern sharing/recording apps can still capture it. See [Apple's documentation](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum/none). No process hiding or proctoring bypass is implemented. Computer-audio text is labeled by input source, not individual participant.

This is early independent software, not feature-for-feature parity with Cluely. No Cluely code, branding, packaged tools or backend endpoints are bundled. Calendar sync, cloud sync, automatic meeting detection and broad capture-app certification are not included. Live paid-provider behavior requires your key and account access. Local builds use a persistent self-signed identity stored on the build Mac. Run `python3 scripts/signing.py setup` once before the first build. Developer ID signing and notarization are not configured.

## All versions

Versioned DMG downloads appear here after actual publication. Previous downloads are preserved; no historical releases are invented.

<!-- VERSIONS:START -->
| Version | Status | macOS download |
| --- | --- | --- |
| 0.1.0 | Newest · local | Not published |
<!-- VERSIONS:END -->

See [release instructions](docs/GITHUB.md), [release history](docs/RELEASES.md), [changelog](CHANGELOG.md), and [verification](docs/VERIFICATION.md). A future “push to GitHub” request defaults to the next patch release; ordinary Git pushes only synchronize commits.

## Architecture

```text
SwiftUI workspace / floating AppKit panel
  ├─ five provider profiles → Keychain → streamed AI adapters
  ├─ AVAudioEngine + ScreenCaptureKit → Apple Speech → transcript
  ├─ requested screenshot → attachment preview → selected provider
  └─ local session store → history / notes / Markdown export
```

Source has no runtime package dependencies. Provider icon assets are pinned and bundled offline with provenance and their license. See [third-party notices](THIRD-PARTY.md). VELIN code and original artwork use the [MIT license](LICENSE).
