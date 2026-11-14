# GitHub-ready source and releases

Open the inner VELIN folder in VS Code. That folder is the Git root. The outer folder holds the one current app, caches, installers and `.velin-workspace`. A normal clone outputs to ignored dist/. Nothing is published until you choose the repository destination and visibility.

Use an empty GitHub repository and add its URL with `git remote add origin YOUR_REPOSITORY_URL`. Build caches, app bundles, DMGs, ZIPs, .env files, keys and user session data are excluded from Git. Use Releases for app downloads. The repository has a local README banner, original icon, license, third-party notices, changelog, CI and VS Code tasks.

The user currently pushes from VS Code and uploads release files manually. Follow [the upload guide](GITHUB-UPLOAD.md). The ready-to-upload files and NOTES.md are grouped by version in the outer outputs/vX.Y.Z folder.

## A versioned release

“Push to GitHub” means a versioned release by default, following AGENTS.md. A normal VS Code Push only synchronizes commits. VERSION and BUILD_NUMBER are the sources of app metadata. Published versions must retain their own main README download rows; normal newest releases get Latest.

1. Add real user-visible changes under `[Unreleased]` in CHANGELOG.md.
2. Run `python3 scripts/release.py prepare` (patch default). An existing prepared version is reused.
3. Run `bash scripts/test.sh` and `python3 scripts/release.py preflight`; review the complete diff.
4. Quit VELIN, then run `bash scripts/build.sh`. Verify the app and appropriate runtime behaviors.
5. Commit the reviewed source on main with your configured identity. Build the Windows preview from that commit with `python3 scripts/build-windows.py` (.NET SDK 10 required). Run `python3 scripts/release.py package` to build the DMG, Windows EXE/ZIP, app/source ZIPs and checksums from that exact clean commit.
6. Mount the DMG read-only, verify VELIN.app signature and Applications shortcut, and unmount. Confirm the metadata and checksums. Developer ID notarization is not configured: the persistent local self-signed identity supports development continuity, not Apple verification or public distribution. Never export or commit its private key.
7. Install/sign into GitHub CLI if needed. Inspect `python3 scripts/release.py publish --dry-run`. Then use `python3 scripts/release.py publish` when publication is authorized. This pushes main/tag without force, stages a draft, uploads absent assets, publishes Latest, verifies assets, and commits the real download catalog. Never overwrite a published version or force a historical tag.

The 0.1.0 baseline is local and archived; 0.1.1 has a verified published macOS release. The 0.1.2 release is published for Mac and Windows. Version 0.2.0 adds local multilingual speech and per-mode personalization; Windows runtime verification is still pending. No repository URL, download link or historical release is invented. The initial release notes are in release-history.json. Upload the current prepared version and preserve earlier local archives; future release requests use a patch.

## GitHub appearance

Suggested description: “A free, open-source macOS and Windows personal AI workspace with live transcription, screenshot questions, local meeting notes, and five secure bring-your-own-key connections.”

Suggested topics: macos, windows, dotnet, winforms, swift, swiftui, appkit, ai-assistant, meeting-notes, speech-recognition, screen-capture, bring-your-own-key, apple-silicon.

The repository owner's avatar is separate from the app logo and README. `Resources/icon.png` is the app/avatar artwork; docs/assets/readme-banner.svg is the original banner. Setting a profile avatar or repository visibility is a separate user choice.
