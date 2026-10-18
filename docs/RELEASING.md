# Releasing Hello Mini

Hello Mini uses the MIT license. The first public release is [0.1.0 (build 1)](https://github.com/emmettl/hellomini/releases/tag/v0.1.0), published on 13 September 2026. It is Developer ID-signed, notarized, and has been tested from a browser download on the physical Mini. The steps below apply to subsequent releases. Build CI remains separate from distribution: public checks and the private Mini runner use ad-hoc signing and have no distribution credentials.

For **0.3.0**, physical Wokyis validation is explicitly deferred until the device arrives. Release notes must preserve that limitation; development-Mac testing and automated checks do not establish legibility on the device.

**0.4.0** was published on 15 September 2026. Its tiny-screen fixes came from testing on the Wokyis, and the published build was then checked on the device and looks fine.

**0.5.0** was published on 1 October 2026 (Europe/Zurich), with Communications and ambient-animation fixes. Hosted CI passed; physical-Mini format, test/Metal, build and bundle steps passed. The private workflow's artifact upload hit GitHub Actions storage quota; the separately uploaded signed/notarized release assets were verified and published successfully.

**0.6.0** release source is dated 18 October 2026 (Europe/Zurich), with MiniPaint, desktop presets, Scrapbook transfers, picture round trips, desktop patterns from drawings, and explicitly added example scraps. Validation evidence is recorded in the GitHub release notes. Longer-session and physical Wokyis checks remain follow-ups.

**0.7.0** release source is dated 18 October 2026 (Europe/Zurich), with Network, Finder inspection/favourites, saved-session recovery, event-driven Scrapbook OCR and CI/documentation maintenance. Exact validation and remaining hardware limitations are recorded in the release notes. Release packaging now extracts the ZIP into a fresh location and rechecks its signature, stapled ticket and Gatekeeper acceptance before creating the versioned archive.

**0.8.0** source is dated 18 October 2026 (Europe/Zurich). Validation evidence and remaining hardware/self-hosted coverage limits are recorded in its GitHub release notes.

**0.9.0** adds Finder transfers, portable presets, Living dither and recovery guidance. Report actual accessibility/hardware validation in release notes; deterministic lifecycle gates do not establish a long physical sleep/wake soak. No GitLab test instance is available.

The [dated Mini validation record](WOKYIS_VALIDATION.md) distinguishes virtual-display checks from physical Wokyis coverage and records the manual-install/Homebrew upgrade trap. It also records physical resolution/display-sleep/DarkWake checks and post-0.9 layout fixes; full system sleep remains unverified. Check the running executable and display identity before starting hardware validation.

**0.10.0** adds saved Chooser services, optional CPU instruments, a 1.5× comparison preset, responsive sheets and display-window recovery fixes. The physical comparison supports retaining 2× on the Wokyis. See [0.10 validation](0.10_VALIDATION.md) for evidence and remaining VoiceOver, full-system-sleep and soak gaps.

**0.11.0** adds active-window keyboard/accessibility isolation, Finder sheet focus restoration, guarded session-only Finder Undo and optional Physical windows. See [0.11 validation](0.11_VALIDATION.md) for passing automated/live checks and the remaining spoken VoiceOver, full-system-sleep, cable hot-plug and soak limits.

## One-time signing setup

The release machine needs a valid **Developer ID Application** certificate with its private key. An Apple Development certificate is not sufficient. Obtain the identity through your Apple Developer account/Xcode and install it in that machine's Keychain. Configure a `notarytool` Keychain profile interactively; avoid putting passwords in scripts or committing signing material.

```sh
security find-identity -v -p codesigning
xcrun notarytool store-credentials "HelloMini-notary"
```

Apple documents [Developer ID distribution](https://help.apple.com/xcode/mac/current/en.lproj/dev033e997ca.html) and [custom notarization workflows](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow). This project's script enables the hardened runtime, submits a ZIP, staples the accepted ticket to the app, and checks Gatekeeper before making the final ZIP. It adds no entitlement exceptions.

## Build a candidate

1. Review the source, license notices, changelog, and application behaviour at 720p. Check the intended commit's hosted CI and physical-Mini tests before publication.
2. Set `CFBundleShortVersionString` and `CFBundleVersion` in `Support/Info.plist`, then commit the release source. Keep the bundle identifier stable to preserve existing preferences. The version is a numeric `major.minor.patch`; the build number is a positive integer.
3. Quit the running app and configure the identity and Keychain profile:

```sh
export HELLO_MINI_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export HELLO_MINI_NOTARY_PROFILE="HelloMini-notary"
make release-check
make release
```

`release-check` performs local preflight checks; the profile's credentials are verified only during submission. `release` requires a clean checkout, runs the checks, builds the app, verifies arm64 metadata, signs it with a timestamp and hardened runtime, submits it to Apple, validates the stapled ticket and signature, and checks Gatekeeper acceptance. It stops on errors and will not overwrite a versioned archive. No GitHub tag, upload, or publication happens automatically.

Output uses the version from `Support/Info.plist`. For example, 0.1.0 produced:

```text
dist/Hello-Mini-0.1.0-macos-arm64.zip
dist/Hello-Mini-0.1.0-macos-arm64.zip.sha256
dist/Hello-Mini-0.1.0-macos-arm64.json
```

The manifest records version, build, source commit, architecture, minimum OS, checksum, and signing/notarization status. The checksum names only the downloaded ZIP, so it can be verified from the download directory. License and third-party notices are included inside the application.

If notarization rejects the app, inspect `dist/notarization.json` and retrieve the submission's log. If a wait times out, use `notarytool history` and `info` with the same Keychain profile to find the pending submission before submitting again. Do not treat a timed-out submission as accepted.

## Review and publish

Extract the final ZIP to a fresh location and test that copy. Before publication, validate a browser-downloaded candidate on a Gatekeeper-enabled Mac, including first launch, Metal rendering, Control Panel, file dialogs, and saved data across upgrades. Use screenshots containing only demonstration content; avoid publishing personal Finder paths, private CI projects, or Scrapbook contents.

Create a GitHub draft release targeting the manifest's exact source commit. Attach the ZIP, checksum, and manifest, and use the changelog as the release notes. Review the draft before publishing the version tag. Public app releases are never published automatically by pushes or PRs. Installing an app build on the Mini is separate from running its build CI.

After publication, verify the release is public, the ZIP is downloadable, and [hellomini.app](https://hellomini.app) offers the expected version. The website reads GitHub’s latest stable release endpoint and updates its download link automatically. Check the changelog, installation guide, and roadmap for stale release status.

## After publishing: update Homebrew

This distribution channel was added on 18 October 2026 for the already-published 0.8.0 binary. Strict online audit, style, isolated Homebrew installation, signature, stapled-ticket and Gatekeeper checks passed; no replacement app release was needed.

The cask lives in [emmettl/homebrew-tap](https://github.com/emmettl/homebrew-tap), as `Casks/hellomini.rb`. After verifying the public release, run:

```sh
python3 scripts/update-homebrew-tap.py 0.8.0 --dry-run
make release-tap VERSION=0.8.0
brew update
brew audit --cask --strict --online emmettl/tap/hellomini
brew style emmettl/tap/hellomini
```

Use the newly published version, without `v`. The helper requires host `gh` credentials with write access to the tap. It refuses draft/prerelease versions, mismatched manifests/checksums, and downgrades; downloads the published ZIP and verifies its SHA-256 before committing through the GitHub Contents API. Updates use the current blob SHA so concurrent edits fail safely. Repeating an unchanged version is a no-op. `--dry-run` performs the same verification without writing. A failed tap update can be retried without rebuilding or republishing the app.

`packaging/homebrew/hellomini.rb` is the bootstrap template; existing tap metadata is preserved on version updates. Keep its architecture, macOS minimum, URL and app name aligned if packaging changes. The cask deliberately has no `zap` stanza: uninstalling it retains Scrapbook data, preferences, backups and Keychain tokens. Check installation in a disposable app directory with `brew install --cask --appdir=/tmp/hellomini-brew-check emmettl/tap/hellomini`, then uninstall that test copy. Never overwrite an existing user installation during release validation.

Release preparation remains local; it does not publish GitHub releases or update Homebrew. Updating the tap is the final distribution step after publication. Follow the [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook) when changing cask metadata.
