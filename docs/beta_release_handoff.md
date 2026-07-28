# Beta Release Handoff

The Beta 1 release work is paused while `main` is changing rapidly. The work is preserved on a clean branch and in an isolated worktree; no stash is required.

## Preserved state

- Branch: `beta/0.1.0-beta-1`
- Worktree: `/Users/brandontran/Dosey/.slim/worktrees/beta-0.1.0-beta-1`
- Local and remote branch head: `2a43ba0a291a0deceb2dadc6ab720bb2827d9f54`
- Original base: `89951848fe0cac8f5646a1f00520bd0072e959d6`
- Last observed remote `main`: `6781b79654f9783b0b18fb68d76bde75dcf32ae9`
- Worktree status: clean, tracking `origin/beta/0.1.0-beta-1`, with no merge in progress

Relevant commits:

- `63b225a` — `chore(mobile): prepare Dosey beta 1`
- `2a43ba0` — `chore(mobile): use Dosey app icon`

Existing stashes belong to unrelated work and were not changed. Do not apply or delete them as part of this release work.

## Source changes

Commit `63b225a` made four release metadata changes:

- `mobile_app/dosey_app/pubspec.yaml`: version `0.1.0+1`
- `mobile_app/dosey_app/android/app/src/personal/res/values/strings.xml`: `Dosey Beta 1`
- `mobile_app/dosey_app/android/app/src/robot/res/values/strings.xml`: `Dosey Robot Beta 1`
- `mobile_app/dosey_app/ios/Runner/Info.plist`: display name `Dosey Beta 1`

Commit `2a43ba0` replaced the existing launcher assets with the classic logo from `media/dosey-logo-01-classic.png`:

- Five Android legacy mipmaps under `mobile_app/dosey_app/android/app/src/main/res/mipmap-*/ic_launcher.png`
- Fifteen iOS icons under `mobile_app/dosey_app/ios/Runner/Assets.xcassets/AppIcon.appiconset/`

The generated icons are opaque, preserve the source composition, and use an edge-matched deep-navy background. No adaptive Android resources, dependencies, manifests, or asset-catalog metadata were added.

## Verification completed

Before the icon-only amendment:

- `flutter analyze` passed.
- All 1,014 Flutter tests passed. Existing Drift multiple-database warnings were present but did not fail the suite.
- Personal and Robot Android debug builds passed.
- `flutter build ios --debug --no-codesign` passed.

After replacing the icons:

- Personal and Robot Android debug builds passed again.
- The iOS debug no-codesign build passed again.
- Icon dimensions, opacity, composition, and required iOS sizes were checked, including the 1024×1024 marketing icon.
- Full analysis and tests were not repeated because the amendment changed only PNG assets.

Verified application metadata:

| Target | Identifier | Version | Label |
| --- | --- | --- | --- |
| Android Personal | `com.sloppybobbert.dosey_app` | `0.1.0` (`versionCode` 1) | `Dosey Beta 1` |
| Android Robot | `com.sloppybobbert.dosey_app.robot` | `0.1.0` (`versionCode` 1) | `Dosey Robot Beta 1` |
| iOS | `com.sloppybobbert.doseyApp` | `0.1.0` (build 1) | `Dosey Beta 1` |

Both Android APKs are debuggable and use the Android debug signer:

`SHA-256 5e33709adcee00e3fde3d9420285b9c2091b2e8a37be917e833894a10e21f405`

The iOS build is intentionally unsigned; no IPA, signing identity, or provisioning profile was created.

## Local artifacts

The current icon-bearing universal APKs are ignored build outputs under:

`mobile_app/dosey_app/build/beta/v0.1.0-beta.1/`

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `Dosey-Personal-0.1.0-beta.1-debug.apk` | 176,743,936 bytes | `fc21459161699b14e1270c1186c8c0d24aa3c21d7e54efd06affd5736fb1ffc0` |
| `Dosey-Robot-0.1.0-beta.1-debug.apk` | 176,743,768 bytes | `c026a8b7b35a5883859d120229c4b77bba2bf53da7e7ce77081fff026cffe0ec` |

`SHA256SUMS.txt` in that directory passes for both APKs.

The rejected ARM64 split-ABI candidates remain under:

`mobile_app/dosey_app/build/beta/v0.1.0-beta.1-arm64/`

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| Personal ARM64 APK | 102,363,415 bytes | `d45ef7b1497b4ab7c202c423aa78619b4f951959fe3373898aa4de68f82b5cc8` |
| Robot ARM64 APK | 102,363,247 bytes | `320d0ae267bcfc6f4edde5fd41e07bc26e8f3c4ecbef5727f658c993d2edb678` |

Do not release these split-ABI candidates: Flutter changed their Android `versionCode` from 1 to 2001. If a future release needs smaller ARM64-only APKs, build for ARM64 without `--split-per-abi` and verify that the intended version code is preserved.

The ignored beta build directories total about 532 MB. They are intentionally preserved for this handoff.

## Local environment

The worktree contains an ignored `.env` with the four public Appwrite identifiers required by the Android flavors. It has mode 600 and was validated without exposing values.

Do not commit the `.env`, print its values, or copy it into release assets. A future clean worktree will need its own ignored copy.

## Incomplete public prerelease

The public prerelease is incomplete and predates the icon commit:

- URL: <https://github.com/SloppyBobbert/Dosey/releases/tag/v0.1.0-beta.1>
- Release database ID: `360760238`
- Tag: `v0.1.0-beta.1`
- Annotated tag object: `278eb9e29f134c72ba9eaf3d2d32c78f9337794b`
- Tag target: `63b225aad7fe922fcaa4e9164be2e8d1f851ee8e`
- Downloads observed: zero for every asset

Current server assets:

| Asset | Asset ID | State | Size | Digest |
| --- | ---: | --- | ---: | --- |
| Old Personal APK | `492065822` | uploaded | 176,692,198 bytes | `sha256:a466b92b219a7c111acebe131fe7aecd08cb050030d656fa1c9129c46f01c848` |
| Old `SHA256SUMS.txt` | `492065778` | uploaded | 205 bytes | `sha256:926d2be9b77fd9b744aeeb68ec301cd466eff6363540f18e904b4422803b4278` |
| Old Robot APK | `492068333` | starter/incomplete | 176,692,030 bytes | none |

Upload history:

1. A combined `gh release create` upload failed with `tls: bad record MAC` and left no release.
2. Creating the release first allowed the checksum and Personal APK to upload, but the Robot APK failed with the same TLS error.
3. A final bounded attempt used the GitHub release-assets REST endpoint with `curl --http1.1`; it failed with `Send failure: Broken pipe` and left the incomplete `starter` asset.

Further blind retries were stopped. The incomplete prerelease and stale tag should be deleted only after fresh explicit approval. Do not treat this release or tag as a valid starting point for a later beta.

## Why work paused

PR #51 added the Personal Mode foundation after this beta branch was created. It did not directly conflict with the beta metadata or icon files, but it changed shared mobile behavior, tests, CI, and platform/role handling. `main` continued advancing after that review, so the existing binaries no longer represented the current application.

A merge from the then-current `main` was discussed and briefly approved, but cancelled before any fetch or merge command ran. Nothing from newer `main` has been integrated into this branch.

## Restarting a beta later

1. Inspect the incomplete prerelease and tag. With explicit approval, remove them rather than reusing stale `v0.1.0-beta.1` state.
2. Create a fresh clean worktree and release branch from the current `main` at that time.
3. Choose a fresh beta version and release name. Reapply the appropriate version and launcher names instead of blindly copying Beta 1 metadata.
4. If the classic mobile icon is still wanted, cherry-pick `2a43ba0` or regenerate its exact changes against current assets after checking for conflicts.
5. Copy the required public Appwrite configuration into an ignored, mode-600 `.env` without exposing its values.
6. Run the current project setup, `flutter analyze`, and the full Flutter test suite from the new worktree.
7. Build both Android flavors and an iOS debug no-codesign build using the current project instructions.
8. Verify package and bundle identifiers, labels, version name/code, ABI coverage, debug or release signing identity, icon assets, iOS unsigned status when applicable, and SHA-256 checksums.
9. Use a reliable distribution path. If GitHub release uploads remain unreliable, prefer an approved CI uploader or another explicitly selected method rather than repeated local retries.
10. Create and verify a new tag and prerelease only after the rebuilt artifacts represent current `main`.

Keep this worktree, its ignored `.env`, and its ignored build artifacts until their removal is separately approved.
