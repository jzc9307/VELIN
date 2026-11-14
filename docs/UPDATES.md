# In-app updates

VELIN 0.2.1 build 7 is the first updater-capable build. Existing installations need this release installed once. Later updater-capable versions check public GitHub Releases during the launch animation, then show a compact update card above the AI provider card. No GitHub account, token or source checkout is needed.

Click **Download & restart** to download the platform's prebuilt app. The progress screen shows actual received bytes, supports cancellation, and verifies the signed release descriptor, artifact length and SHA-256 before installing. Stop Listen/Mic, finish the current AI answer and send or clear any question/screenshot draft first; restarting is blocked while they are active. It does not download or install automatically during a meeting.

On Mac, a signed helper validates the app identifier, version/build and the existing local certificate identity, waits for the old process to exit, and replaces only the app bundle contents. Failed replacement validation restores the previous Contents. The previous copy is retained in a hidden `.VELIN-update-….noindex` sibling folder for recovery. A new Developer ID identity requires an explicit migration; this updater does not silently rotate code-signing identities.

On Windows, a separate copy of the installed executable performs the update after the original exits. The signed manifest authenticates the downloaded EXE even though Windows Authenticode signing is not configured. Atomic replacement keeps a `.previous` executable for recovery. Windows installation, UI and actual restart behavior remain untested on a Windows device; it is a preview.

The app must be in a writable location. An app running from a mounted DMG or protected directory cannot replace itself; install it into an appropriate Applications/user folder first. VELIN does not request elevation or weaken OS protections. System security prompts may still appear. User keys, settings, history and downloaded models are outside the application and are not part of a replacement.

## What you upload each release

`python3 scripts/release.py package` creates the normal downloads plus **VELIN-update.json**. Its payload contains the version/build, release notes, exact Mac ZIP/Windows EXE URLs, sizes and hashes. A dedicated P-256 key signs that payload. Only the public key is in source and installed apps; the private key stays in the release Mac's login Keychain and is restricted to the cached signed `VELINReleaseSigner` tool.

For every published version, upload all of these from `outputs/vX.Y.Z/`:

- `VELIN-X.Y.Z-macOS-arm64.dmg` — first-time manual install.
- `VELIN-X.Y.Z-macOS-arm64.zip` — required by the Mac in-app updater.
- `VELIN-X.Y.Z-Windows-x64.exe` — required by the Windows in-app updater.
- `VELIN-X.Y.Z-Windows-x64.zip` — portable bundle with guides and notices.
- `VELIN-X.Y.Z-source.zip`.
- **`VELIN-update.json` — required to authenticate the update.**
- `SHA256SUMS.txt`.

Use the prepared version's exact tag (`vX.Y.Z`), keep the generated names, and publish a normal stable Release as **Latest** after every asset is uploaded. A Git push alone does not publish an app update. A draft, prerelease, missing descriptor, incomplete download or invalid signature cannot trigger installation. Do not manually edit the signed descriptor or replace an already published artifact. Package again before publication if its artifacts change, preserving older local preparations first.

Release notes and artifact URLs live inside the signed descriptor; no automatic executable code is fetched from the source repository. Download redirects are limited to HTTPS GitHub release hosts and carry no API credentials. Checks are bounded and offline launch remains usable. Both platforms reject older versions/builds and unknown signing keys. Same-version build updates work only when the release was not already published; normal future releases should advance the semantic version.

## Signing continuity

The user approved creation of the dedicated key once. It is separate from the main app's code-signing identity and provider API keys. `python3 scripts/update-signing.py public` prints only the public verification key. `scripts/generate-update.py` uses the trusted signer to sign metadata during packaging; it never exports private key bytes. Keep the release Mac/login Keychain safely backed up. Losing this key prevents installed clients from authenticating a newly generated one; do not silently replace the public key or promise key recovery. Users would need a deliberate manually installed trust migration.

## Verification

Tests exercise cross-platform signatures, tampered payloads, invalid destinations/versions, modified download hashes and rollback using temporary fixtures. The actual Mac helper validates a separately signed newer-app fixture in `--verify-only` mode without replacing the user's app. This is not a completed public old-to-new update on customers' computers, nor Windows runtime acceptance. Keep those distinctions when announcing the feature.

## About and refresh

About shows the installed version and build, the latest public version returned by GitHub, when the last check completed, and a Refresh action using the same authenticated update flow. A local build ahead of the public release is labeled accordingly. Failed/offline checks show unknown instead of claiming to be current. What’s new is bundled for the installed version and works offline; it is not replaced by the notes of a newer release. Verified newer updates can be installed from About or the sidebar.
