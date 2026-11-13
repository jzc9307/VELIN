# User guide

## Compact assistant

The default assistant is a slim floating bar with a prompt, Screen, Listen, mode/provider menus, History and Settings. A reply expands below the bar only after asking. Use the chevron to collapse/reopen the latest answer. The full conversation stays in the workspace. Drag the emblem/background or use Command + arrow keys to reposition the bar. Movement shortcuts register only while the assistant is visible and are released when it is hidden. When hidden mode is off, the menu-bar VELIN emblem provides Listen, Show/Hide, Hidden Mode, History and Preferences.

## Short answers and prepared actions

Ask normally in the floating assistant. Your question appears in a chat bubble, followed by a direct answer (usually one or two sentences). Explicit requests for more detail or code can still receive a longer answer. Optional **Say this**, **Next step**, and **Explain more** views are prepared after the answer within the same provider request. Each chip becomes available when its content is ready; clicking a ready chip switches the local view immediately, without another request. Initial generation and preparation still depend on provider/network speed and can use additional output tokens. No separate speculative requests are made.

Answers begin at the top. Streaming does not force scrolling to the bottom; scroll down yourself for a longer reply. Switching to a different prepared view starts that view at the top. The answer area is moderately transparent (80% dark fill with the usual 97% input opacity), with bright text and darker controls. The input bar keeps its original opacity. Copy copies the currently selected view.

Prepared views remain with the message in local history and Markdown exports. Older long replies open with their first paragraph and retain their full text under Explain more. A provider that does not follow the optional-view format still shows its answer; unavailable actions stay disabled. Meeting mode favors a short spoken answer instead of automatically listing questions and next steps. The full context stays in your saved conversation.

## Workspace

The workspace opens at 920 × 680 points and can resize down to 800 × 560. The original oversized saved frame is migrated once; later window sizes are remembered. Navigation scrolls on shorter windows, Overview cards reflow, and AI Connections uses a connection menu in compact windows.

Overview opens the assistant, listening, capture and connection setup. Session has Conversation, Transcript and Notes tabs. New session preserves the current session and starts a fresh one after listening and generation stop. History searches titles, conversation, transcript and notes. Reopening a session allows continuing it.

## AI and privacy

Up to five connection profiles contain provider/model/base URL metadata; only macOS Keychain holds the secrets. Change provider before pasting its key. Save connection retains it; Use this connection chooses the active destination. No automatic failover or key rotation occurs. Keys are editable in secure fields and excluded from exports. .env.example is documentation, not a plaintext credential store.

Scrollbars are hidden throughout the workspace and assistant. Scroll with the trackpad, wheel, or keyboard to reach content below the window.

For Gemini, **Refresh models** requests Google's model catalog using the connection's saved key (or its current replacement draft). It sends no chat or screenshot and makes no generation request. Select a model from **Models**, save, then **Test**. The catalog describes supported methods; project access, quota and billing can still restrict a listed model. The test sends only a short connection-check prompt. Gemini 2.5 Flash/Pro are legacy models restricted to prior users as of November 2026; current suggestions use newer Flash models. Nothing silently switches an existing profile or retries another provider. Google HTTP errors show a bounded explanation with the request credential removed; arbitrary endpoint bodies are not shown.

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
