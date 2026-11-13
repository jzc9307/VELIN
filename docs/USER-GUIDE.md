# User guide

## Compact assistant

The default assistant is a slim floating bar with a prompt, Screen, Listen, mode/provider menus, History and Settings. A reply expands below the bar only after asking. Use the chevron to collapse/reopen the latest answer. The full conversation stays in the workspace. Drag the emblem/background or use Command + arrow keys to reposition the bar. Movement shortcuts register only while the assistant is visible and are released when it is hidden. When hidden mode is off, the menu-bar VELIN emblem provides Listen, Show/Hide, Hidden Mode, History and Preferences.

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

## Hide and show

Use Control + Option + Space, Escape, the bar's close button, or the menu-bar Show/Hide item. The bar fades with a slight 3% shrink and 6-point downward motion over 140 ms, preserving its desktop position. Reduce Motion removes the movement/scale. Repeated presses reverse the requested state; an old hide completion cannot dismiss a newly shown bar. Hiding the bar does not stop a listening session.

## Hidden mode

The bar's eye button, menu-bar Hidden Mode item, and Privacy → Hidden mode control the same saved setting. Enabling it animates the visible bar to 97% size over 180 ms and removes VELIN's Dock/app-switcher presence and menu-bar icon. The assistant remains usable. Disabling it restores the full-size bar and both icons. Reduce Motion disables the size change. This mode persists across relaunches; hiding/showing the bar does not change it.

With both icons hidden, press Control + Option + Space to reopen the bar and click its eye button to restore the icons. Alternatively reopen VELIN.app in Finder, then use Privacy in the workspace. If macOS reports a shortcut conflict, the workspace shows the conflict and this Finder recovery still works. No listening, screenshot or AI request starts when recovering the UI.

Hidden mode also sets Apple's legacy NSWindow sharing hint on the workspace and assistant. Apple does not guarantee this excludes content from capture. A recording/sharing app may still include VELIN. The process stays visible in Activity Monitor. Compare the actual recipient's output for your exact app/OS/version, including restarted captures.

## Data and recovery

settings.json stores non-secret settings/context and sessions.json stores session text under Application Support/VELIN. Writes are atomic with owner-only filesystem permissions. Data is not separately encrypted by VELIN; macOS account/disk protection still matters. Corrupt files are preserved and a visible error blocks overwrites. Back up the folder before manual recovery. Local API keys remain in Keychain when rebuilding the app. There is no cloud sync, meeting calendar integration or account/paywall service.
