# Verification · 13 November 2026

Build: VELIN 0.1.0 (1), Apple Silicon, tested on macOS 27.0.1 with Apple Command Line Tools. The app targets macOS 14+. Older supported macOS releases have not been independently tested.

## Automated checks

`bash scripts/test.sh` passes **52 checks**:

- 40 request/schema, image encoding, streaming transport, credential destination, storage and export checks. Responses, Claude Messages, Gemini GenerateContent and compatible Chat Completions are exercised against a synthetic localhost provider. Redirect forwarding is rejected.
- 5 release metadata/history tests, including idempotent preparation and rejection of missing release notes.
- 7 profile/error regressions: blank Gemini editor preserves a key; explicit replacement persists; metadata/key status survives reload; a provider switch requires its own key; the five-slot cap holds; settings JSON contains no key; long API errors collapse an empty failed answer.

Keychain tests create random, synthetic credentials and remove them afterward. No real key or private content is included in test fixtures. Paid-provider compatibility has not been tested against real remote accounts in this task.

## Native app verification

Observed in the running app:

- Original setup, tutorial, provider logos, workspace and compact assistant render.
- Microphone, Speech Recognition and Screen & System Audio permission flows work after user approval. Audio starts/stops; transcription quality and long-call accuracy have not been benchmarked.
- Requested screen capture produces a preview, which can be removed without sending. No captured image was transmitted to an external AI provider during verification.
- Closing the workspace and reopening History/Preferences from the floating bar succeeds. Prior reports showed stale NSWindow access after close; the app now retains its windows with isReleasedWhenClosed=false.
- An existing Gemini connection displays its saved-key status, and saving a blank replacement field succeeds without clearing it.
- The custom menu-bar controls, tactile button styles and visible-assistant movement hotkeys are implemented. Haptic intensity depends on the Mac's hardware/settings.
- A long synthetic provider error stays within the fixed-width panel; a failed empty response collapses to the compact bar. A nonmodal banner replaces the global error popup.
- Page header aligns with native window controls. The page has curved upper/lower left joins against the sidebar.

The source and installed app have passed codesign --verify --deep --strict. This is ad-hoc local signing, not Developer ID notarization. The current app is `../VELIN.app`; a single-instance guard prevents launching independent duplicate instances. Only one physical current app exists in the Project workspace. The obsolete staging registration was removed; system search can retain stale cached suggestions temporarily. Builds preserve the outer app directory identity to reduce future duplicate cached entries.

## Release artifacts

The local release consists of a DMG containing VELIN.app and an Applications shortcut, an app ZIP, a source ZIP from the recorded Git commit, and SHA-256 checksums. The installer is mounted read-only and its app signature/metadata/shortcut verified before handoff. Source excludes app bundles, caches, user sessions, keys and real environment files. No GitHub repository or release is created automatically.

## Practical limits

- Capture exclusion is a legacy OS hint, not a guarantee of invisibility in every recorder or meeting app.
- Inputs are attributed as You and Computer; individual remote participants are not diarized.
- On-device Apple speech model availability varies by language/system. Unsupported local recognition fails explicitly.
- Model IDs are editable suggestions; availability, vision support, billing and retention depend on the selected provider.
- Local session data uses owner-only filesystem permissions, not a separate application encryption password.

## Visibility update · 13 November 2026

The current source/app adds a 140 ms fade, 3% shrink and 6-point downward transition for hiding/showing the assistant, with the existing bar position preserved. Reduced Motion disables movement/scale and keeps a short fade. The bar eye button and menu-bar Hidden Mode item control the existing legacy capture-exclusion request; the bar shows a dashed mint indicator while enabled. This remains best effort and does not establish compatibility with every screen-sharing app.

All **56 checks** pass: the previous 52 checks plus four visibility-state regressions covering repeated show calls, stale hide completions, rapid reversals, and final hide settlement. The rebuilt app passed signature verification. Native UI checks confirmed the new eye control toggles from Off to Hidden mode requested / On and that the bar remains usable. No real provider request or recording was started during this update.

The current VELIN.app is updated in place. Existing 0.1.0 installer/source archives remain the earlier local baseline; a new versioned package will be prepared for the next release request.

## Complete hidden-mode presentation · 13 November 2026

The current app now removes its Dock/app-switcher presence using NSApplication's accessory policy and hides its NSStatusItem while hidden mode is enabled. Disabling the mode restores regular activation policy and the status item. The visible assistant scales to 97% over 180 ms on the eye-button mode change, separate from the existing hide/show fade; Reduce Motion disables the scale. The saved mode is applied at launch after the status item is created. A failed policy change leaves the menu-bar recovery control available and reports an error.

All 56 existing checks and release preflight pass, and the rebuilt current app passes strict signature verification. Native UI testing confirmed saved hidden mode at launch, repeated eye-button On/Off toggles, retained Gemini/history data, and recovery to usable controls after closing windows. A read-only NSRunningApplication query independently confirmed accessory policy while enabled, regular policy when disabled, and that the process remains running with windows closed. The system Dock/menu-bar accessibility inspection timed out; icon presence is implemented through the documented AppKit APIs rather than verified through those system accessibility trees. Targeted computer-use key injection does not establish physical global-shortcut behavior. No real provider request or capture session was started. The final app is left with hidden mode enabled.

Reference APIs: [activation policy](https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum) and [status-item visibility](https://developer.apple.com/documentation/appkit/nsstatusitem/isvisible). This does not establish capture exclusion across meeting/recording applications.

## Compact workspace · 13 November 2026

The workspace now starts at 920 × 680 points (previously 1220 × 840) with an 800 × 560 minimum. A one-time preference migrates the old oversized frame; later manual sizes are restored. Native screenshots confirmed the new default at 1840 × 1360 Retina pixels. The sidebar scrolls on shorter windows, labels stay on one line, Overview cards use an adaptive grid, AI Connections uses a compact connection picker below 800 points of page width, and setup uses a narrower illustration column. The existing Gemini key is still recognized and the saved session remains present. The computer-use resize-drag API returned noWindowsAvailable, so the minimum-size bound and physical drag behavior were not independently verified through that API.

All 56 existing checks pass, release preflight passes, and the current app is rebuilt with ad-hoc signature verification. No live AI request or recording was made. The current app and source remain version 0.1.0 (1); earlier installer archives are unchanged.

Duplicate-search investigation found one VELIN app bundle in the Downloads/Documents/temporary build locations, one metadata-search result, and one Launch Services registration, all pointing to the canonical current app. Its registration was refreshed and that app was reimported into Spotlight without resetting other apps or user data. The user confirmed that two visual suggestions remain after the targeted refresh. A broader display-name/registration/build-location search still found one current app. The system Spotlight app could not be launched by computer use. Apple’s folder-reindex procedure was attempted through Search Privacy, but the folder chooser kept Choose disabled; it was cancelled and the exclusions list remains empty. The second result’s Show in Finder location is needed to distinguish a stale suggestion from an unindexed copy. No search-history deletion, global index reset, or user-data deletion was performed.

## Duplicate search-record repair · 13 November 2026

The user confirmed that Show in Finder for both VELIN search icons reveals the same current app. Launch Services garbage collection was run. A targeted file-record repair then temporarily moved the closed app into a hidden app path inside a temporary .noindex directory on the same volume. A metadata query while excluded returned no VELIN app paths. The identical app was restored to its original path, reregistered and imported. Its outer inode and executable SHA-256 remained unchanged, and strict signature verification passed. Afterwards metadata search and Launch Services each returned exactly the canonical current app path. VELIN reopened successfully with its existing Gemini connection and saved session visible. No other applications, source files, settings, keys, history or global index were reset.

The system search UI repeatedly timed out under computer use. The user was asked to confirm the number of icons after the complete targeted repair. Until that check is received, visual duplicate removal remains unverified. No claim of a second installed app or of confirmed UI cleanup should be made.

## Gemini connection and scrollbar update · 13 November 2026

The user reported Gemini HTTP 404 with gemini-2.5-flash and a visible native scrollbar in compact settings. Google’s current documentation limits Gemini 2.5 Flash/Pro generation access to prior users. The app now suggests current Flash IDs and allows explicit Gemini model-catalog refresh with the draft or saved credential. Catalog requests paginate, deduplicate, filter generateContent support, reject malformed IDs/repeated tokens, and never forward credentials across redirects. Catalog presence does not establish project generation eligibility. Existing saved models are not automatically migrated.

HTTP errors now distinguish authorization, missing model/route/access, quota and server failures. Only the official HTTPS Google endpoint may supply its bounded JSON error message, after removing the request credential and token-like substrings. Custom endpoint response bodies are not echoed. The connection result clears on model/endpoint edits and successful save; starting a test clears the stale global error.

Native runtime verification: the existing connection was explicitly saved with gemini-3.5-flash-lite, preserving the user’s entered key in Keychain. An initial test before rebuilding still displayed 404, so the cause of that transient result was not established. After rebuilding, Refresh models loaded 49 catalog entries, and the short generation test visibly returned “Connected · gemini-3.5-flash-lite · OK”. Only the fixed connection-check prompt went to Google; no chat history, screenshots, documents, or audio were sent. No full conversation request was made for verification. Existing saved sessions remained visible.

SwiftUI’s scrollIndicators(.hidden) alone left the native track visible on this host. The app now uses a shared NSHostingView subclass that removes vertical/horizontal NSScrollView scrollers during layout, alongside SwiftUI’s hidden indicator setting. The final native screenshot confirmed the connection editor has no scrollbar; the accessibility tree also contains no scrollbar element. This keeps standard scrolling enabled in the native scroll view. The computer-use wheel API returned noWindowsAvailable, so physical trackpad/wheel behavior was not independently verified by automation.

All **67 checks** pass: 55 core/transport checks (11 new normalization/catalog/error/privacy regressions), 5 release checks and 7 profile/error checks. The final source passes release preflight and diff whitespace validation. The current app passed strict ad-hoc signature verification. Version remains 0.1.0 (1); versioned historical installers are unchanged.

Sources checked: [Google model deprecations](https://aistudio.google.com/docs/deprecations#gemini-2.5-flash-models) and [Models API](https://aistudio.google.com/api-reference/models/list-models).

## Concise conversational replies · 13 November 2026

Normal questions now request a 1–2 sentence direct answer before optional Say this / Next step / Explain more content in the same provider stream. The optional sections are parsed into message fields; split delimiters never appear as UI text, partially prepared actions remain unavailable, cancellation preserves useful partial content, and plain provider replies fall back safely. Optional views are cached with the message, included in later conversational context and Markdown exports, and decode alongside earlier sessions without these fields. Ready chips change local view state only; no request is made on selection. There is no promise of zero initial provider latency. Notes retain their separate generation behavior.

The floating assistant shows the question in a right-aligned bubble, a short answer beneath it, and rounded action chips. Inline Markdown and block headings/lists/fenced examples render without raw heading markers. The answer scroll view starts at the top and does not follow generated tokens to the bottom; manual scrolling remains available. A new message or selected action starts at the top. The workspace scrolls once to the new user question rather than following each text delta. Older long replies open on their first paragraph and retain full text under Explain more. The answer fill is 17 percentage points lighter than the input opacity, with a 68% minimum for readability; the error banner stays dark.

All **80 automated checks** pass: 67 core/transport checks, 5 release checks, and 8 profile/error/stream-persistence regressions. New checks cover cached-view separation, partial markers, cancellation, omitted sections, unstructured responses, legacy decoding, reload, export, and the full synthetic stream into persisted history. Release preflight and diff validation pass. The app is locally ad-hoc signed; no release version or historical installers were changed.

Runtime verification: a fresh “What is JSON?” query streamed successfully using the active Gemini connection. Its saved main answer was 35 words, with all three optional views present in the same message. No captured image or audio was attached to that verification query. Native screenshots confirmed the new question bubble, concise answer, lighter panel and ready chips during subsequent user interaction. Selecting Say this visibly replaced the main text with the prepared response and selected that chip. The source path for this selection performs no network call. No latency benchmark or physical wheel/trackpad test was recorded; top anchoring is implemented by stable scroll identity and removal of per-token bottom scrolling. Existing user sessions, context and keys were preserved.

Installation was initially blocked because VELIN reopened during compilation. The signed update was then staged in an ignored temporary .noindex directory, installed only after the process closed, and verified in place while preserving the canonical app directory. Temporary staged copies were removed after success.

## Stable local identity and audio repair · 13 November 2026

The user approved creation of a persistent, non-extractable local signing private key in login Keychain for /usr/bin/codesign, without changing system certificate trust. Current builds use a certificate-pinned designated requirement instead of an ad-hoc content hash; two changed test bundles had different CDHashes but the same designated requirement and passed strict verification. The signed app was installed in place. This is local development signing, not Developer ID signing or notarization. Existing API-key items may need one new user approval via Always Allow. A saved-key catalog request succeeded after reopening, returning 49 models; the final updated/reopened app also successfully answered a user-submitted request using the saved connection.

The user explicitly approved resetting only VELIN’s Microphone, Speech Recognition and ScreenCapture TCC records, and manually regranted them. All three checks remained Allowed after multiple signed app updates. No API key, configuration or session data was reset.

Audio diagnostics showed both inputs delivered buffers while no words appeared. A repeated legacy recognition retry could repeatedly reconnect to the local speech service; logs also reported service resource errors. Recognition errors are now domain-aware and terminal unless they represent a sufficiently long no-speech segment. Retry work is delayed and cancelled on stop. Per-source errors remain visible, and a failed source does not stop a working source. macOS 27 uses independent continuous local SpeechTranscriber analyzers for supported languages; previous systems/languages retain the legacy path. Live levels and transcription preview distinguish receiving audio from producing words.

Runtime verification: an eight-second synthetic spoken phrase was played in QuickTime Player. Both the initial corrected legacy computer-audio path and the continuous analyzer produced visible text. The continuous engine transcribed the complete phrase twice, including a replay after more than a minute of silence. The final transcript contained both sets of Computer lines. Both source streams remained active; native Transcript later showed multiple meaningful You lines, and the user confirmed words labeled You appear. An actual Teams call still requires separate confirmation. The user corrected an earlier mistaken success selection, so it is not counted as a passed test. No call audio, transcript or screenshot was sent to an AI provider during these checks. The Mac’s default input was the built-in microphone while output used EarPods; VELIN now displays the input device name.

All **88 checks** pass: 67 core/transport, five release, and 16 profile/audio checks. New audio checks cover RMS boundaries, cancellation/domain-specific restart handling, owned two-channel audio buffers after capture reuse, and CMSampleBuffer conversion preserving frames/channels. These do not establish microphone acoustics, call transcription accuracy, or long-call reliability.

API references: [Apple speech task errors](https://developer.apple.com/documentation/speech/sfspeechrecognitiontask/error) and [SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer).

## Enter-to-answer listening workflow · 13 November 2026

The user clarified that Listen is intended to bring the interviewer’s question into Conversation so Enter can request an answer without typing. Computer speech is now collected as an unanswered live draft in Conversation and the compact assistant. Enter in VELIN, the Answer button, or the existing global Control+Option+Return uses that text as the actual user question. Microphone text remains context, typed text takes priority, and no provider request starts from speech alone. Finalization of a partial already submitted does not repeat it. Starting Listen selects Conversation; the full transcript remains separately accessible.

All **97 checks** pass (67 core/transport, five release, 25 profile/audio/workflow). Synthetic-provider integration verifies that empty submission answers computer speech, microphone speech does not initiate a request, typed questions take priority, malformed endpoints preserve pending speech, and new sessions clear drafts. These are isolated fixtures and transmit no real call content. Native verification on the final build showed the live recognized question with Answer ↵ in the floating bar. The user confirmed that Enter answers it. Conversation then visibly contained the question labeled Other Side followed by a concise JSON explanation from the selected Gemini provider. The user initiated this final provider request; the agent did not submit captured call content. A transient Gemini high-demand error was also observed during user interaction. It is a provider availability issue and is not treated as a transcription failure. The saved credential was usable after updating and reopening the app. Both microphone and computer audio preferences were restored to On after the isolated synthetic test; capture was stopped.

## 0.1.1 release preparation · 13 November 2026

The user requested a manual GitHub handoff: source remains in the canonical inner folder for VS Code, and the agent must not publish. Version is 0.1.1 (build 2), using the existing patch/idempotent preparation workflow. The README leads with free/open-source Cluely-alternative positioning, clearly distinguishes provider API costs, and does not claim a benchmarked speed advantage or universal capture invisibility. LobeHub provider marks retain their MIT license/provenance; no third-party executable or model is bundled.

Panel resizing now responds to section visibility rather than every transcript delta. The header has a fixed 120-point layout, and each 60 Hz resize tick applies a complete frame with the same top edge, revealing content below it over 240 ms. Microphone audio-engine preparation runs on a dedicated background queue, leaving UI animation responsive while inputs start. Meeting and provider menus share the same label component, typography, icon sizing and height. Reduce Motion uses immediate resize without movement.

All **99 checks** pass (69 core/transport/geometry, five release, 25 profile/audio/workflow). The two new geometry regressions cover top-edge preservation and expanded content constrained to a smaller display. Native screenshots confirmed matching toolbar typography/alignment and the unchanged input/toolbar positions before/after Listen expansion. The running app showed immediate Starting/Connecting feedback, then active local audio sources. No AI request was made by the agent during these UI checks. Frame-rate/latency benchmarking and the older SDK CI path have not been independently measured; the CI path now compiles without installing signing credentials and gates the SDK-27-specific speech code for older compilers.

The release DMG is to be mounted read-only, with its app version/signature, Applications link and installation text checked before handoff. The package manifest identifies the exact source commit. Local self-signing is retained; Developer ID signing/notarization remains unconfigured. No GitHub upload is claimed.

### Stop-listening and Keychain follow-up

The user confirmed the corrected bottom-only transition matches the requested behavior. The live strip now follows recording/starting state only; a pending question no longer keeps stopped audio controls visible. The unanswered text remains in Conversation, and stopping preserves the full transcript. This adds one regression: the standard suite now passes **100 checks** (69 core/transport/geometry, five release, 26 profile/audio/workflow).

The user reported that Always Allow still repeated despite the earlier certificate-pinned app signature. A read-only, service-scoped access-control inspection found legacy partition entries tied to individual executable CDHashes. Therefore the earlier successful catalog reads did not establish cross-build approval continuity.

After automatic approval review rejected a broader credential-access design, the user explicitly approved a bundled VELIN-only credential component with same-signature client checks and existing provider-item scope. The component uses NSXPCConnection code-signing requirements before connection resume, a matching user ID, and reciprocal service verification. It validates UUIDs and addresses only app.velin.assistant.providers items. It joins the application’s audit session so standard macOS Keychain authorization can appear. No real key data was logged, exported, written to settings/source, or queried by the security fixtures. It installs no login item, system daemon, all-app access, or certificate trust change.

Three signed runtime checks pass: an authorized VELIN identity queried a random absent slot; a different app identity signed with the same certificate was rejected; changing the main app’s sealed resource changed its CDHash while the embedded credential executable stayed identical and worked. Raw credential-store regressions use only disposable synthetic items. Component bytes are cached separately from UI versions; validation-only builds preserve the signed cache. The user approved VELIN Keychain with Always Allow, and a native catalog read then visibly returned 49 models. The subsequent changed-production-app read is checked before the release handoff.

## Screenshot input and editable speech drafts · 14 November 2026

The question field now uses a native first-click-focus control. A later user test found that the nonactivating panel could leave keyboard ownership with Codex, so that panel style is removed; a real click activates VELIN, makes the panel key, and gives the clicked editor first-responder status. Merely showing the floating bar still does not explicitly activate VELIN. Attaching a screenshot requests keyboard focus. Submission is handled only by the Enter command or explicit Send, rather than the text field’s generic action/end-editing path. A native test visibly attached a screenshot, typed a follow-up, opened a mode menu, and retained the unsent draft/image without starting a response. Native testing initially exposed an accessibility-label recursion and an unintended focus-change submission to the selected Gemini connection; both were corrected before the final installed input build. The unintended screenshot submission was disclosed to the user.

The live computer-speech question is a scrolling native editor in the assistant and Conversation. Manual edits are kept separately from incoming recognition, which continues to update the raw transcript. Enter submits the corrected question; Shift+Enter inserts a line break. Resume live returns to the latest recognized draft. New live text follows the end only when the reader is already there, preserving manual browsing; edited text is never replaced by recognition updates. Draft text is bounded to 6,000 characters, while raw session transcript remains separate. Screenshot-only requests now choose screenshot context instead of unrelated pending speech. Button hit targets, press borders, fill contrast and spring feedback are stronger.

All **106 standard checks** pass: 69 core/transport/geometry, five release, and 32 profile/audio/workflow checks. Six additional regressions cover manual correction/finalization, Resume live and protected empty edits, bounded long draft continuation, corrected Enter input, attachment-without-generation, and screenshot precedence. No real image/audio is used by the fixtures. The signed Keychain component was reused unchanged; no credential access policy changed. The user confirmed that the live text is editable and corrections stay in place as more speech arrives. A native screenshot/typing/focus-change check passed without another request. The same-signature credential component remains reused unchanged. Meeting/provider native menus now also have explicit rounded hover borders/backgrounds to match the other compact controls.

The current app/source contain these Unreleased fixes. The already packaged 0.1.1 DMG/source archive remains preserved from its original commit and is not silently overwritten. Manual release-table instructions were added to docs/GITHUB-UPLOAD.md, including real asset links, previous-release preservation, catalog synchronization, and documentation-only pushes.
