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
