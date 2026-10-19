# Releasing Hello Mini

Public releases are Developer ID-signed, notarized and uploaded to [GitHub Releases](https://github.com/emmettl/hellomini/releases). The Homebrew tap is updated only after the stable release is public and its assets are verified. Build CI is separate: it uses ad-hoc signing and holds no distribution credentials.

Record release-specific evidence in a dated validation document and link it from the release notes. The [validation index](VALIDATION.md) and [physical Wokyis record](WOKYIS_VALIDATION.md) distinguish actual hardware tests from remote/automated checks. Check the running executable and display identity before hardware validation; report untested VoiceOver, sleep/wake, hot-plug and soak work explicitly.

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

Output uses the version from `Support/Info.plist`:

```text
dist/Hello-Mini-<version>-macos-arm64.zip
dist/Hello-Mini-<version>-macos-arm64.zip.sha256
dist/Hello-Mini-<version>-macos-arm64.json
```

The manifest records version, build, source commit, architecture, minimum OS, checksum, and signing/notarization status. The checksum names only the downloaded ZIP, so it can be verified from the download directory. License and third-party notices are included inside the application.

If notarization rejects the app, inspect `dist/notarization.json` and retrieve the submission's log. If a wait times out, use `notarytool history` and `info` with the same Keychain profile to find the pending submission before submitting again. Do not treat a timed-out submission as accepted.

## Review and publish

Extract the final ZIP to a fresh location and test that copy. Before publication, validate a browser-downloaded candidate on a Gatekeeper-enabled Mac, including first launch, Metal rendering, Control Panel, file dialogs, and saved data across upgrades. Use screenshots containing only demonstration content; avoid publishing personal Finder paths, private CI projects, or Scrapbook contents.

Create a GitHub draft release targeting the manifest's exact source commit. Attach the ZIP, checksum, and manifest, and use the changelog as the release notes. Review the draft before publishing the version tag. Public app releases are never published automatically by pushes or PRs. Installing an app build on the Mini is separate from running its build CI.

After publication, verify the release is public, the ZIP is downloadable, and [hellomini.app](https://hellomini.app) offers the expected version. The website reads GitHub’s latest stable release endpoint and updates its download link automatically. Update the changelog, dated validation record and [validation index](VALIDATION.md). Review installation, user guide and roadmap claims against the released behaviour; keep the README a version-independent project overview.

## After publishing: update Homebrew

The cask lives in [emmettl/homebrew-tap](https://github.com/emmettl/homebrew-tap), as `Casks/hellomini.rb`. After verifying the public release, run:

```sh
RELEASE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Support/Info.plist)"
python3 scripts/update-homebrew-tap.py "$RELEASE_VERSION" --dry-run
make release-tap VERSION="$RELEASE_VERSION"
brew update
brew audit --cask --strict --online emmettl/tap/hellomini
brew style emmettl/tap/hellomini
```

Run from the checkout used for the published release; confirm `RELEASE_VERSION` matches that release, without `v`. The helper requires host `gh` credentials with write access to the tap. It refuses draft/prerelease versions, mismatched manifests/checksums, and downgrades; downloads the published ZIP and verifies its SHA-256 before committing through the GitHub Contents API. Updates use the current blob SHA so concurrent edits fail safely. Repeating an unchanged version is a no-op. `--dry-run` performs the same verification without writing. A failed tap update can be retried without rebuilding or republishing the app.

`packaging/homebrew/hellomini.rb` is the bootstrap template; existing tap metadata is preserved on version updates. Keep its architecture, macOS minimum, URL and app name aligned if packaging changes. The cask deliberately has no `zap` stanza: uninstalling it retains Scrapbook data, preferences, backups and Keychain tokens. Check installation in a disposable app directory with `brew install --cask --appdir=/tmp/hellomini-brew-check emmettl/tap/hellomini`, then uninstall that test copy. Never overwrite an existing user installation during release validation.

Release preparation remains local; it does not publish GitHub releases or update Homebrew. Updating the tap is the final distribution step after publication. Follow the [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook) when changing cask metadata.
