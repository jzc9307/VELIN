# Changelog

## [Unreleased]

No pending changes.

## [0.2.0]

- Make Listen computer-audio-first, with a separate optional microphone toggle that can change without restarting the meeting stream; migrate the original two-input default once and preserve later explicit choices.
- Reduce the gap between assistant controls and live speech, retaining the fixed top edge and downward animation.
- Add an optional, entirely local multilingual Whisper engine for Malay, Mandarin, English and experimental Malaysian code-switching, with bounded audio buffering, a bundled warm worker, integrity-checked Base/Small model downloads and editable output. No cloud audio upload; mixed-language accuracy remains limited and Windows runtime needs verification.
- Add a separate About me section and a local guided introduction builder using only supplied facts, with optional age.
- Add interview, behavioral/coding interview, system design, case interview, recruiter screen, recruiting, team meeting and lecture modes. Give each mode its own instructions, response language and context files; preserve previous settings/files with their selected mode.
- Preserve new Chinese continuation text after answering a live partial question.
- Restore the README app logo and illustrated banner, and record the verified published v0.1.2 Mac and Windows downloads.

## [0.1.2]

- Introduce a native Windows x64 preview with a self-contained portable EXE, five Credential Manager AI connections, streaming chat, screenshots, local history/notes/export, editable speech drafts, local microphone/default-output recognition, tray recovery and global shortcuts. Cross-compiled and shared-core tested; Windows runtime testing remains required.
- Restyle the README with a centered product introduction, platform/feature badges, quick navigation and a clear free-app message. Preserve published macOS downloads and add separate Windows preview release tracking.
- Package both platforms under one version, with portable Windows ZIP/notices, exact-commit source and SHA-256 checksums.

- Keep the editable floating assistant eligible to join other apps’ full-screen Spaces and Stage Manager sets, and restore its ordering after Space changes.

- Transfer keyboard focus to VELIN when clicking the question or transcript editor, including over another app; focus the question after screenshot attachment, and prioritize screenshot questions over unrelated pending speech.
- Make live spoken questions editable and scrollable; preserve corrections while transcription continues, with Resume live and a bounded newest-text view.
- Increase button hit targets, hover contrast, press borders and spring feedback, with matching hover borders/backgrounds on the Meeting and AI-provider menus.

## [0.1.1]

- Collapse live audio status when Listen stops while preserving the transcript and unanswered question in Conversation.
- Keep Keychain reads in a stable VELIN-only authenticated component, avoiding build-hash approvals for normal UI updates. macOS may require an initial component approval.

- Pin the input and toolbar while only the bottom edge expands or collapses. Prepare the microphone engine away from the main UI thread to avoid Listen startup stalls.

- Smoothly animate opening and closing the answer, listening, screenshot and error sections, preserving the top toolbar position and respecting Reduce Motion.
- Align Meeting and AI provider menus with consistent typography, icons and control heights; show immediate Listen startup feedback.
- Prepare a free/open-source GitHub README, manual upload guide, versioned DMG/ZIP/source/checksum bundle and release notes.

- Put the other side’s recognized speech into Conversation and the compact assistant. Press Enter to answer without typing, with live/final deduplication and the existing global answer shortcut.

- Use continuous on-device speech on macOS 27 for supported languages, keeping microphone and meeting streams separate. Stop retrying failed legacy requests in a tight loop and retain individual input errors.
- Show the actual microphone device, separate audio meters, and live transcript text so input setup can be diagnosed before a call.

- Keep local app identity stable across rebuilds with a certificate-pinned signing identity, preserving Keychain trust after one authorization.
- Show live transcription, separate microphone/computer meters and input status directly in the assistant.
- Keep a working audio input running if the other fails, show the failure, and keep full transcription accessible separately from Conversation.
- Stage signed updates without touching the running app, avoiding repeated compile/close cycles.

- Stream a concise answer first, with Say this / Next step / Explain more prepared in the same request and revealed by rounded local-action chips.
- Show the user's question above the overlay answer, keep streaming anchored at the top, and preserve manual scrolling without bottom jumps.
- Make the answer area more transparent than the input bar and render Markdown block headings, lists and code cleanly.
- Preserve optional reply views in local history and exports, with compatibility for earlier sessions and providers that return plain text.

- Hide native scrollbar tracks and indicators while retaining trackpad, wheel and keyboard scrolling.
- Refresh Gemini's paginated generation-model catalog from the selected endpoint, with header-only credentials and redirect blocking.
- Update Gemini suggestions, normalize model IDs, and explain model-access, authorization, quota and endpoint failures with redacted Google diagnostics.
- Clear stale connection results when editing or saving settings.

- Launch the workspace at a compact 920 × 680 size, with a smaller resize limit, scrollable navigation, and adaptive Overview/AI Connections/setup layouts.
- Migrate the original oversized window frame once and preserve subsequent manual resizing.

- Hide VELIN’s Dock/app-switcher and menu-bar icons in hidden mode; restore both when disabled, with keyboard/Finder recovery.
- Animate the eye-button mode change to a slightly smaller assistant, respecting Reduce Motion.

- Add a 140 ms fade/shrink/slide transition for assistant hide and show, with reduced-motion support.
- Add an eye control and dashed border for hidden mode (best-effort capture exclusion).
- Protect rapid visibility toggles from stale animation completions without changing the bar's saved position.

## [0.1.0]

- Introduce the original native VELIN workspace, icon, guided setup, and five-step practice tutorial.
- Connect up to five AI profiles with provider/model selection and macOS Keychain storage.
- Stream responses from OpenAI, Claude, Gemini, OpenRouter, Groq, and compatible local/custom services.
- Listen to microphone and computer audio with on-device Apple speech recognition by default.
- Attach a reviewed screenshot, personalize modes and context, generate notes, and export local session history.
- Add global shortcuts, menu-bar controls, transparent capture-exclusion limitations, and versioned release tools.

### Initial build verification fixes

- Keep workspace and assistant windows alive after closing so History, Preferences and app reopen remain safe.
- Preserve saved keys when an editor is reopened or saved with a blank replacement field.
- Keep long errors within the compact bar and collapse empty failed responses.
- Align the compact page header with the native window controls and restore curved sidebar/page seams.
- Use tactile hover/press feedback, VELIN menu-bar controls, Command-arrow movement and a single-instance guard.
