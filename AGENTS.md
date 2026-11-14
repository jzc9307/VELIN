# VELIN project instructions

## Canonical workspace

This is the one editable source tree and Git root. Locally it lives at `Project/VELIN/VELIN`; the parent contains `.velin-workspace`, the current `VELIN.app`, `work/`, and `outputs/`. In a fresh clone build output belongs in ignored `dist/`. Preserve the user's sessions, notes, context, API slots and Keychain data. Never reset user data for tests; use isolated fixtures.

## Product standard

Keep the workspace compact (920 × 680 default, 800 × 560 minimum), preserve subsequent manual sizes, and adapt page layouts without clipping. Keep VELIN's original dark mint/lilac design, custom signal emblem, compact native controls, readable aligned layouts, press feedback, and accessible labels. Use bundled provider logos with credits. Hide scrollbar tracks/indicators while retaining scrolling. Lead with a concise answer, keep streaming at the top without forced bottom scrolling, and prepare optional reply chips within the same request. Ready chips must switch locally without another network call; do not promise zero initial provider latency. Gemini catalog listing is explicit and does not guarantee project generation access; never silently switch a saved model. The original workflow reference is Cluely, but do not copy its code, branding, packaged assets, proprietary backend calls or tutorials. Do not promise invisibility: capture exclusion is a best-effort legacy OS hint. Hidden mode also hides the Dock/app-switcher and menu-bar icons, with a slight assistant shrink. Preserve Control+Option+Space and app-reopen recovery; disabling the mode restores both icons. Global hotkeys need no Accessibility permission. Never start capture at launch or silently send screenshots/audio to a provider.

## AI connections

At most five connection profiles. The key belongs only in macOS Keychain, addressed by profile UUID. Never add credentials to Codable configuration, logs, .env, README, tests, Git or screenshots. Provider switches clear the draft key. Preserve per-slot credentials and explicit active-provider selection; never auto-rotate keys or bill an unexpected provider. No account or subscription service is necessary for VELIN itself.

## When the user says “push to GitHub”

Treat that as a request for the next versioned app release unless the user explicitly requests code-only. Normal Git pushes/commits do not bump versions automatically.

1. Read current user instructions, Git status/diff, origin, branch/tags, VERSION, BUILD_NUMBER, and `.release/prepared.json`. Use the intended destination and visibility; never create a public repository or change visibility without the user's chosen destination.
2. Write real user-facing notes under `[Unreleased]` in CHANGELOG.md. Default to a patch (`0.1.0 → 0.1.1 → 0.1.2`). Run `python3 scripts/release.py prepare`; existing preparation must be resumed without bumping twice. Only use minor/major when requested or appropriate to agreed scope.
3. Run `bash scripts/test.sh`, `python3 scripts/release.py preflight`, and appropriate app/runtime checks. Review the diff for secrets/private data and unintended resources. Build with `bash scripts/build.sh` after quitting VELIN. Preserve the one current app filename.
4. Commit the reviewed source/version changes on main using the user's existing Git identity. Run `python3 scripts/release.py package` from the clean commit. Each release includes a versioned macOS DMG with an Applications shortcut, app ZIP, source ZIP, and checksums. Mount the DMG read-only and verify the app, signature and shortcut before publication. Keep the main README All versions table and docs/RELEASES.md synchronized. No fake public download links.
5. Inspect `python3 scripts/release.py publish --dry-run`, then publish when authorized. It creates/preserves an annotated version tag, pushes without force, uploads to a draft, and publishes normal versions with Latest. Never replace a published tag or asset. Resolve incomplete release state by inspecting remote tag/assets before retrying. Preserve every historical DMG link in the main README.
6. Developer ID signing/notarization is not configured for this local build. State that limitation honestly and complete the necessary signing/distribution work before claiming Apple verification. Preserve third-party icon license and provenance.
7. Report actual version, commit, release URL, tests, and limitations. Never claim publication without a service-confirmed result.

## Commands

- `python3 scripts/signing.py setup`: explicit, one-time per-Mac setup for a non-extractable local signing key in login Keychain. Creating/importing a new signing identity requires the user's explicit approval. Private keys and local signing references must never enter Git or exports. No system trust-store changes.
- `bash scripts/build.sh`: compile and sign with the persistent configured identity; never silently fall back to ad-hoc signing (which changes Keychain/TCC identity on rebuild).
- `bash scripts/build.sh --stage-only`: prepare a signed .noindex app for an immediate swap after closing the current process.
- `bash scripts/test.sh`: request/stream/storage tests plus release tests (uses synthetic localhost server).
- `python3 scripts/release.py plan|check|preflight|prepare|dmg|package|publish`.
- `python3 scripts/release.py publish --dry-run`: preview publication without remote changes.

GitHub CLI authentication is needed only to publish. Do not store its credentials here. Do not push until the user supplies/chooses the repository destination.

## Manual GitHub upload

The user currently pushes source themselves from VS Code and uploads the prepared DMG through GitHub Releases. Keep source in the canonical inner folder. Prepare versioned assets and NOTES.md in outer outputs/vX.Y.Z; do not push or create a repository for this manual-upload request. After the user supplies an actual published release URL, verify the remote release/tag/assets, update the main README download history plus its mirrors, and remove the matching prepared record. If a future release request finds a pending version already published manually, complete that record first, then prepare the next requested release.

## Credential component continuity

The user explicitly approved the VELIN-only XPC credential component after reviewing its scope. Keep its source contract independent of the main app: only the app identifier signed with the same certificate may connect, with the same-user check and reciprocal service verification. Restrict item access to app.velin.assistant.providers and validated profile UUIDs. Preserve JoinExistingSession for the standard macOS authorization UI. Reuse the signed broker from the source/toolchain/signing-identity cache across UI updates; never remove LC_UUID or re-sign/modify an unchanged helper. Changes to its actual implementation may require a new user Keychain approval. Never allow arbitrary clients, broaden Keychain partitions to all apps, export a real key, or claim approval survives an OS Keychain reset. Run python3 Tests/check_credentials.py for the isolated signed IPC checks; it queries only a random absent slot.

## Windows preview

Windows source lives under Windows/ in this same repository. Build with .NET SDK 10 using python3 scripts/build-windows.py; keep Windows keys only in per-user Credential Manager, never JSON/source. Preserve the five-profile cap and explicit-send behavior. VERSION and BUILD_NUMBER drive both platforms. The portable self-contained EXE/ZIP joins the same exact-commit release/checksums folder. Cross-compilation and core tests are not Windows runtime verification: retain preview labeling until real Windows audio/UI tests pass, and document the smaller feature set. Keep dependency/runtime license notices in the Windows ZIP. Never claim capture invisibility or Mac/Windows feature parity. CI may build artifacts, but does not automatically publish releases.

## v0.2 personalization and local speech

About me is shared background; instructions/output language/files belong to each mode. Migration must preserve legacy text/files with the previous mode and keep later empty edits empty. Never bake the user's biography into Git/screenshots/docs. Biography assistance is a local fact-only builder; age is optional. Listen defaults to computer audio, with a separate optional microphone; do not restart the computer stream for a mic toggle. Native single-locale speech remains available. Mixed-language Whisper uses a pinned local worker over bounded private pipes, optional integrity-checked weights outside Git, no sockets/keys/cloud audio, and explicit experimental labeling. Never claim perfect Malaysian code-switching. Preserve first-click focus, manual transcript edits, full-screen overlay eligibility and top-anchored animation.
