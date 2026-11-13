# Upload VELIN from VS Code

The inner `Project/VELIN/VELIN` folder is the source repository. Open that folder in VS Code. The current app stays in `Project/VELIN/VELIN.app`; versioned release downloads are in the outer `outputs/vX.Y.Z/` folder.

## Push the source

1. Create an empty repository in your GitHub account, choosing its visibility yourself.
2. Connect this existing source repository through VS Code’s Source Control view, or add the GitHub remote URL in its terminal.
3. Push the existing main branch. Keep keys, `.local-signing.json`, user data, app bundles and caches out of the repository; `.gitignore` already excludes them.

## Upload the prepared release

1. Open your repository’s **Releases → Draft a new release**.
2. Create the tag **vX.Y.Z** using the version in `VERSION`, targeting the pushed main commit. Use **VELIN X.Y.Z** as its title.
3. Paste `outputs/vX.Y.Z/NOTES.md` into the description.
4. Attach `VELIN-X.Y.Z-macOS-arm64.dmg`, `VELIN-X.Y.Z-macOS-arm64.zip`, `VELIN-X.Y.Z-source.zip`, and `SHA256SUMS.txt`. `manifest.json` records the exact packaged source commit for your reference.
5. Mark a normal release **Latest** and publish when ready. Keep earlier releases and their downloads intact.
6. Give the actual published release URL to your coding agent so it can verify the assets, add the real DMG link to the main README, synchronize `docs/RELEASES.md` / `release-history.json`, and complete the prepared-release record. Until then the README correctly marks it prepared and unpublished.

The source folder is ready to push. A local DMG is not evidence of a published GitHub Release. No app binaries or DMGs belong in regular Git source history.

## Next release

Add real changes under `[Unreleased]`, prepare the next patch once, run checks, build, commit, and package. The exact commands are in [GITHUB.md](GITHUB.md). Retry a pending version instead of bumping twice. Plain VS Code Push only synchronizes source commits.
