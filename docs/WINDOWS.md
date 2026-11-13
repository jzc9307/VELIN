# VELIN for Windows · Preview

**First Windows version: v0.1.2.** Earlier releases are macOS-only.

**Free app. No VELIN account or subscription.** Your selected AI provider bills API usage separately. A local Ollama connection is optional.

## Download and open

Use the **Windows-x64.zip** from the release you choose. Extract it into a folder you own and open **VELIN.exe**. The separate EXE download is the same portable application; the ZIP also includes the guide and dependency notices. There is no installer or admin requirement. Keep the notices with redistributed copies.

Requires **Windows 11 x64** with a working desktop audio device. The executable includes its .NET 10 desktop runtime; a separate .NET installation is not needed. The app is currently **unsigned** and may trigger Windows reputation checks. Check the published checksum before deciding whether to run it. An ARM64 build is not included.

This initial Windows implementation was cross-compiled on macOS. Its shared request/storage/draft/stream tests and PE format checks pass. **It has not been run on Windows yet.** Audio devices, speech language packs, focus, high-DPI layout, shortcuts, capture exclusion and antivirus acceptance require Windows testing. macOS test results do not establish Windows behavior.

## First use

1. Open **AI Connections**, choose a provider, enter an available model ID and API key, then **Save connection**. Keep up to five profiles; selecting a saved profile in the assistant changes the active provider. Keys stay in your Windows account’s Credential Manager, not settings JSON.
2. Open **Audio & Permissions**. Choose microphone and/or computer audio, enter your installed recognition language (for example `en-US`), and save while Listen is stopped.
3. Install the matching local Windows Speech recognizer through **Settings → Time & language → Speech** if needed. This preview uses classic installed Windows Speech engines, not cloud dictation. Windows language support differs from macOS. Missing engines fail with an explanation rather than silently uploading audio.
4. Open the floating assistant and start **Listen**. Computer audio captures the PC’s default output, including a meeting running on that device. Microphone supplies your own side as context. A separate phone call is not captured digitally.
5. Correct the live computer-speech text if necessary, then press **Enter** in VELIN or **Ctrl+Alt+Enter** from another app. Speech alone does not start an AI request. **Resume live** restores recognition text after a correction.
6. To ask about the screen, press the screenshot button, review the attachment, type a question and press Enter. Changing focus does not submit it.

For Teams or another meeting app, route its output to the Windows default playback device before starting Listen. Restart Listen after changing devices. Multiple speakers/apps share the Computer label. Local speech quality and long-call reliability have not been benchmarked.

## Shortcuts

| Action | Windows shortcut |
| --- | --- |
| Show / hide assistant | Ctrl + Alt + Space |
| Ask / answer pending question | Ctrl + Alt + Enter |
| Start / stop Listen | Ctrl + Alt + L |
| Attach a screenshot | Ctrl + Alt + S |
| Answer in the question / speech editor | Enter |
| Add a line in the speech editor | Shift + Enter |

Shortcuts can conflict with other software. Tray controls remain available. Close hides the workspace/assistant; use **Quit VELIN** to exit. The assistant requests topmost ordering; exclusive full-screen apps can obscure it.

## Preview scope

Included: streaming chat; OpenAI Responses, Claude Messages, Gemini and compatible endpoints; five saved connections; Credential Manager keys; local sessions/search/Markdown export; notes; screenshot attachment; local microphone and default-output transcription; editable pending speech; locally cached reply chips; hover/press borders; tray recovery; animated downward expansion.

The native Mac onboarding/tutorial, provider-logo presentation, document imports, Gemini model-catalog browser, transparent material, Mac hidden-mode behavior, speech engines and Command-arrow movement are not Windows features in this first preview. Windows answers currently display plain text/Markdown source. Test these differences before choosing the Windows preview for a call.

Capture exclusion is an optional request to supported Windows capture APIs, **not universal invisibility**. The tray icon remains present for recovery. Provider model IDs are suggestions, and an account may lack access. Save/test or AI requests use your selected endpoint; HTTPS is required except loopback local servers. Redirects are blocked.

Local sessions and preferences live in `%LOCALAPPDATA%\VELIN`. Windows account/file permissions apply; VELIN adds no separate session encryption. Only explicitly requested AI answers/notes/tests send relevant content to your provider. No audio recording files are retained. Screenshots are kept in memory for the next explicit request, not saved as image files by VELIN.

## Build from source

Install **.NET SDK 10**. Python 3 is used by the release helper.

```powershell
python scripts/build-windows.py
```

On macOS/Linux you may cross-compile with the same command and `--dotnet /path/to/dotnet`. EnableWindowsTargeting is set in the project. Output goes to ignored `dist/work/windows-x64.noindex/VELIN.exe` in a fresh clone, or outer `work/windows-x64.noindex/VELIN.exe` in the canonical workspace. The source version and build number drive both platforms. Tests can run independently:

```powershell
dotnet run --project Windows/VELIN.Core.Tests/VELIN.Core.Tests.csproj -c Release
```

Report Windows version, device/output, installed speech language and exact error when testing. Never attach API keys or private call transcripts to an issue.
