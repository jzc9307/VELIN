# User guide

## Compact assistant

The default assistant is a slim floating bar with a prompt, Screen, Listen, mode/provider menus, History and Settings. A reply expands below the bar only after asking. Use the chevron to collapse/reopen the latest answer. The full conversation stays in the workspace. Drag the emblem/background or use Command + arrow keys to reposition the bar. Movement shortcuts register only while the assistant is visible and are released when it is hidden. The menu-bar VELIN emblem provides Listen, Show/Hide, capture exclusion, History and Preferences.

## Workspace

Overview opens the assistant, listening, capture and connection setup. Session has Conversation, Transcript and Notes tabs. New session preserves the current session and starts a fresh one after listening and generation stop. History searches titles, conversation, transcript and notes. Reopening a session allows continuing it.

## AI and privacy

Up to five connection profiles contain provider/model/base URL metadata; only macOS Keychain holds the secrets. Change provider before pasting its key. Save connection retains it; Use this connection chooses the active destination. No automatic failover or key rotation occurs. Keys are editable in secure fields and excluded from exports. .env.example is documentation, not a plaintext credential store.

Each question includes recent chat, up to 24,000 characters of transcript context, custom instructions and context files. Screenshots are attached only to the next question, removed from memory afterward, and never stored in history. Requests do not automatically transmit live audio to the AI provider. OpenAI requests set store=false; provider terms/retention still apply. Only HTTPS endpoints and HTTP localhost are allowed. HTTP redirects are rejected so credentials cannot silently follow to a different host.

## Audio

Microphone uses AVAudioEngine. Computer audio uses ScreenCaptureKit. Apple Speech transcribes each input separately; channels re-arm periodically for long sessions. Text is labeled You and Computer, not automatically diarized by participant. Live segments appear before being finalized to history. No WAV/audio recordings are retained.

On-device speech is required by default. Unsupported languages or missing local models fail with an actionable error. You may turn this off in Audio & Permissions to permit Apple speech processing; that is a separate destination from your selected AI service. Stop listening before changing source/language settings. Use the macOS default microphone.

## Context and notes

General, Meeting, Coding, Study, Sales and Custom modes supply editable context. Custom instructions apply alongside the mode. Context files support UTF-8 text/Markdown/JSON and PDFs with extractable text. Up to 20 files; first 12,000 characters each. Scanned PDF OCR is not included. Notes are editable; generating notes sends the available session context to the active AI provider. Imported transcripts are useful when live recognition is unavailable.

## Capture exclusion

Privacy → Request capture exclusion sets Apple's legacy NSWindow sharing hint on the workspace and assistant. Apple explicitly does not guarantee it hides content from capture. A recording/sharing app may still include VELIN, its icon or process. Neither activity-monitor hiding nor proctoring evasion is implemented. Compare the actual recipient's output for your exact app/OS/version, including restarted captures. Sharing a single selected window or a separate display is a different capture scope, not universal invisibility.

## Data and recovery

settings.json stores non-secret settings/context and sessions.json stores session text under Application Support/VELIN. Writes are atomic with owner-only filesystem permissions. Data is not separately encrypted by VELIN; macOS account/disk protection still matters. Corrupt files are preserved and a visible error blocks overwrites. Back up the folder before manual recovery. Local API keys remain in Keychain when rebuilding the app. There is no cloud sync, meeting calendar integration or account/paywall service.
