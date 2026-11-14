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

Press **Listen** while a Teams or other call is running on this Mac. It captures computer audio only and shows a single **Computer** meter plus the other side’s editable words below the toolbar. **Transcript ↗** opens the full meeting transcript. Words appear while Listen stays on; you do not need to stop it. Green meter movement means audio is arriving; **Transcribing** means recognition has returned words. If no words appear, check the selected speech engine, language/model and call output device. A separate phone’s call is not a Mac system-audio input.

Press **Mic** independently to dictate your own question into the top question box. Listen does not need to be running. Mic does not add a second meter or your voice to the meeting transcript. You can type corrections, attach a screenshot and press Enter to send. Stopping either control leaves the other running; neither starts at launch. No AI request or spoken output starts automatically.

Microphone uses AVAudioEngine; computer audio uses ScreenCaptureKit and needs Screen & System Audio Recording permission. Mic needs microphone permission. The Apple engine also needs Speech Recognition permission. No audio recordings are retained. Listen labels the captured output Computer; it does not identify individual participants.

In Audio & Permissions, choose the speech engine. **Local multilingual → Country → Malaysia** recognizes English, Bahasa Melayu and Mandarin with experimental code-switching, using a separately downloaded local model. Recognition arrives in short chunks and may contain mistakes. Apple recognition uses one selected language, with on-device processing required by default. Turning that requirement off permits Apple speech processing; your selected AI provider still receives no live audio. Stop both Listen and Mic before changing speech settings. Mic uses the macOS default input.

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

On macOS 27 and later, supported languages use Apple’s continuous local SpeechTranscriber engine; its language assets are prepared on the first Listen. Earlier systems and unsupported analyzer languages use the legacy speech framework with the on-device preference respected. The newer engine stays local even if that preference is off. Microphone input follows the device used by macOS’s audio engine; Teams can use a different microphone. EarPods output alone does not select the EarPods microphone for VELIN.

You do not need to stop Listen to see words. Computer audio means sounds played by apps on this Mac, including a Teams call; it cannot directly hear a call running only on a separate phone. Listen places the other side’s recognized computer audio directly in Session → Conversation and the assistant’s live question card. Press Enter while VELIN has keyboard focus, click Answer ↵, or press Control+Option+Return from another app to answer without typing. Mic separately dictates into the top question box. The full raw transcript remains under Transcript. No AI request starts until you ask; a typed question takes precedence. Speech already submitted while partial is not repeated when finalized. Listen and Mic report failures independently; one unavailable input does not stop the other control.

The pending question is collected from Computer audio, so a Teams call must run on this Mac with Computer audio enabled. In the floating bar, Answer ↵ becomes available as words arrive. Starting Listen opens Conversation, ready for this workflow.

### Remembered Keychain approval

This build uses a bundled VELIN Keychain XPC component. It accepts only the same-signed VELIN app and accesses only VELIN provider-key items. Existing keys stay in login Keychain. On its first read, approve VELIN Keychain with Always Allow in macOS. Its signed binary is reused across ordinary UI/model updates, keeping the legacy Keychain partition identity stable. A changed component, signing identity, build toolchain, or a Keychain lock/reset can require renewed approval. No login item, all-app credential access, or system trust change is installed.

Stopping Listen smoothly collapses the live audio strip. The full transcript and any unanswered spoken question remain in the session’s Conversation/Transcript pages.

### Edit a spoken question

Click the live question text in the floating assistant or Conversation to correct it. Your edited question is protected while raw transcription continues in the session. Enter requests an answer using the edited text; Shift+Enter adds a line break. Resume live replaces your corrections with the latest recognized text. Long drafts scroll within a fixed area and follow new speech until you edit; the full transcript remains in the session.

After attaching a screenshot, the question field receives keyboard focus. Type the question and press Enter. If you leave it empty, the screenshot is the topic instead of unrelated pending speech.

### Typing into the floating assistant

Click VELIN’s question field or live transcript editor before typing. The click activates VELIN and transfers keyboard ownership from the app underneath; the bar remains floating. Showing the bar alone still avoids explicitly activating VELIN. Screenshot attachment focuses the question field. Only Enter or Send submits a request; switching focus or opening menus does not.

Meeting and provider menus use the same rounded hover border and background as the other compact controls.

## v0.2.0: your background, your mode, your language

Listen now starts with computer audio. The small mic button independently dictates your question, without starting or restarting the meeting stream. The original both-input default migrates once, while later explicit mic choices remain saved. Stop Listen to stop capture; typed questions and Enter behavior stay the same.

In Personalization, About me holds your real background across modes. Help me write it opens a local facts-only form (name, skills, qualifications, experience, goals and optional age). You review/use the result. The button does not call AI. If your biography was previously in Custom instructions, Move current instructions here transfers it into About me.

Select a mode to edit its own instructions, response language and files. Your old instructions/files are preserved in the previously selected mode. They are not silently copied to every new mode. About me plus only the selected mode's context accompanies explicit AI questions/notes. Mac files include text/Markdown/JSON and text-based PDFs; the Windows preview imports text/Markdown/JSON.

For Malay/Mandarin/English or Malaysian mixed speech, Audio & Permissions offers Local multilingual with a one-time model download. Recognition stays local, but buffering and mistakes remain possible. See [language setup and limits](LANGUAGES.md). The native fast engine remains available for one selected language. Merely choosing a language or downloading a model does not start Listen.

### Build 5 clarification: Listen and Mic are independent

Listen is computer-only and appears in the lower panel. Mic is dictation for the top question field; it works without Listen and creates no second microphone transcript. You can correct the dictated question and press Enter. Stopping one control leaves the other running. Starting/stopping does not send AI requests. The settings page shows actual start/stop controls rather than saved source switches.

Local multilingual now has **Country → Malaysia**, covering the English/Bahasa Melayu/Mandarin mix. Select the country/model, save, then use either control. The native engine continues using its own selected single language. Settings changes apply to the next start, and both controls must be stopped to change the engine/model.
