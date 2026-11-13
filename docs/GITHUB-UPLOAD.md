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

## Update the All versions table after a manual release

The table appears between `<!-- VERSIONS:START -->` and `<!-- VERSIONS:END -->` in the main README.md. Publishing a Release in GitHub does not automatically edit a README.

After you publish:

1. Open the actual GitHub Release and expand **Assets**.
2. Right-click the versioned **.dmg** asset and copy its link address. Use the actual asset URL, rather than the source-code ZIP or the release description URL.
3. Put the new version first and mark it **Latest**. Change any previously published Latest row to **Published**, keeping its original DMG link. Leave versions that were never uploaded marked local/unpublished.
4. Update `docs/RELEASES.md` with the same table. In `release-history.json`, set that version’s `url` to the copied DMG asset URL, set its `status` to `Latest`, and set the previous published version to `Published`.
5. Commit and push those documentation changes from VS Code. Do not bump VERSION or BUILD_NUMBER for this documentation-only push.
6. Once the published tag/assets and their packaged commit have been verified, remove only the matching ignored `.release/prepared.json` record. The next release preparation will then advance the patch once. If you want the coding agent to handle steps 3–6, send it the actual release URL and say “record this published release.” It must verify publication first.

For example, after 0.1.2 is actually published, the Markdown table has this shape. Replace the ALL_CAPS placeholders with real copied asset URLs; do not paste the placeholders as working links:

```markdown
| Version | Status | macOS download |
| --- | --- | --- |
| 0.1.2 | Latest | [Download DMG](REAL_0_1_2_DMG_ASSET_URL) |
| 0.1.1 | Published | [Download DMG](EXISTING_0_1_1_DMG_ASSET_URL) |
| 0.1.0 | Local · archived | Not published |
```

Only use Published for a version that actually has a GitHub Release. If 0.1.1 was never published, keep it local and do not invent its link.

To regenerate both tables from the edited catalog without publishing anything:

```bash
python3 -c 'import runpy; release = runpy.run_path("scripts/release.py"); release["sync"](release["catalog"]())'
```

The release preparation step updates VERSION, BUILD_NUMBER, the app plist and the tables together. Ordinary VS Code Push never does this automatically. Always build/package the version you intend to upload, and keep the DMG filename, app version and Git tag consistent.
