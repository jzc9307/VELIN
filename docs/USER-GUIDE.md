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

## Keychain authorization

API keys stay in macOS Keychain. A stable local signing certificate now identifies this Mac's VELIN builds; changing executable contents no longer changes the designated app identity. The first transition from the old ad-hoc build can still prompt. In macOS's VELIN Keychain dialog, enter your Mac login password yourself and choose **Always Allow** if you want future matching VELIN builds to use that saved key. Choosing **Allow** grants only that access. Never send the password in chat. Each saved item may need its own authorization; a locked/reset Keychain, changed signing identity or system privacy policy can require approval again. The local signature does not provide Developer ID notarization.

## Audio

Press Listen while the call is running on this Mac; you do not need to close Teams or stop listening to see words. The floating bar shows live words and separate **You** (microphone) and **Computer** (meeting audio) meters. **Transcript ↗** opens the full live transcript. Green meter movement means audio is reaching that input; **Transcribing** means speech recognition returned text. If audio arrives but no words do, check the selected recognition language and on-device language availability. A silence hint appears after several seconds without a transcript.

Each enabled input starts independently. If one cannot start, VELIN reports it and can continue with the working input. If neither works, it shows the errors and stays stopped. Computer capture requires Screen & System Audio Recording access; microphone and speech need their respective permissions. A separate phone's audio is not a Mac system-audio input. Listen still transcribes only; ask manually to send conversation text to the selected AI provider. No automatic answering or spoken output is enabled.

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

On macOS 27 and later, supported languages use Apple’s continuous local SpeechTranscriber engine; its language assets are prepared on the first Listen. Earlier systems and unsupported analyzer languages use the legacy speech framework with the on-device preference respected. The newer engine stays local even if that preference is off. Microphone input follows the device used by macOS’s audio engine; Audio & Permissions displays its name. Teams can use a different microphone. EarPods output alone does not select the EarPods microphone for VELIN.

You do not need to stop Listen to see words. Computer audio means sounds played by apps on this Mac, including a Teams call; it cannot directly hear a call running only on a separate phone. Listen places the other side’s recognized computer audio directly in Session → Conversation and the assistant’s live question card. Press Enter while VELIN has keyboard focus, click Answer ↵, or press Control+Option+Return from another app to answer without typing. Your microphone remains supporting context. The full raw transcript remains under Transcript. No AI request starts until you ask; a typed question takes precedence. Speech already submitted while partial is not repeated when finalized. Recognition failures stay visible per source; one unavailable input does not stop a working input.

The pending question is collected from Computer audio, so a Teams call must run on this Mac with Computer audio enabled. In the floating bar, Answer ↵ becomes available as words arrive. Starting Listen opens Conversation, ready for this workflow.

### Remembered Keychain approval

This build uses a bundled VELIN Keychain XPC component. It accepts only the same-signed VELIN app and accesses only VELIN provider-key items. Existing keys stay in login Keychain. On its first read, approve VELIN Keychain with Always Allow in macOS. Its signed binary is reused across ordinary UI/model updates, keeping the legacy Keychain partition identity stable. A changed component, signing identity, build toolchain, or a Keychain lock/reset can require renewed approval. No login item, all-app credential access, or system trust change is installed.

Stopping Listen smoothly collapses the live audio strip. The full transcript and any unanswered spoken question remain in the session’s Conversation/Transcript pages.
