# Releasing Hello Mini

Hello Mini uses the MIT license. The first public release is [0.1.0 (build 1)](https://github.com/emmettl/hellomini/releases/tag/v0.1.0), published on 13 September 2026. It is Developer ID-signed, notarized, and has been tested from a browser download on the physical Mini. The steps below apply to subsequent releases. Build CI remains separate from distribution: public checks and the private Mini runner use ad-hoc signing and have no distribution credentials.

For **0.3.0**, physical Wokyis validation is explicitly deferred until the device arrives. Release notes must preserve that limitation; development-Mac testing and automated checks do not establish legibility on the device.

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

A stable notarized download is now available; a Homebrew cask remains future work. A cask will need the published version, URL, SHA-256, app name, Apple-silicon requirement, and macOS 26 minimum. Add a Homebrew installation command to the public docs only once that distribution channel exists.
