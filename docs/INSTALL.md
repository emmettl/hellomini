# Installing Hello Mini

Hello Mini requires **Apple silicon and macOS 26 or later**. The default desktop is 1280 × 720, with a normal minimum window size of 960 × 600. **Tiny-screen mode** offers 2× interface sizing (with a 1.5× comparison preset in 0.10.0) within the normal window or full screen. Optional **Purist mode** uses a fixed 512 × 384 logical desktop. macOS 15 and Intel Macs are not supported.

## Homebrew

```sh
brew install --cask emmettl/tap/hellomini
```

This installs the signed, notarized release from [emmettl/tap](https://github.com/emmettl/homebrew-tap). To update, quit Hello Mini, then run `brew update` and `brew upgrade --cask emmettl/tap/hellomini`. Homebrew uninstall removes the app; saved data and Keychain tokens remain.

If you previously installed manually into `~/Applications`, quit that copy and open `/Applications/Hello Mini.app` after installing with Homebrew. Homebrew does not replace or quit a separate manual installation. Check About Mini for the running version; an old Dock item may still point at the manual copy. Keep the old copy until you have verified the Homebrew installation, then remove or archive it deliberately.

## Download and install

1. Get the versioned macOS ARM64 ZIP from [hellomini.app](https://hellomini.app) or [GitHub Releases](https://github.com/emmettl/hellomini/releases/latest).
2. Expand the ZIP and move **Hello Mini.app** to Applications.
3. Open the moved copy of Hello Mini normally. The public release is Developer ID-signed and notarized by Apple; Xcode and a developer account are not required.

If first launch from Downloads stalls, quit that copy and move the app using Finder before reopening it. A direct translocated launch stalled on the 0.6 validation Mac, while the normally moved copy launched. Keep Gatekeeper enabled; removing quarantine or disabling security checks is not part of installation.

The release also includes a SHA-256 checksum and build manifest. To verify a download, put the ZIP and its `.sha256` file in the same directory and run, for example:

```sh
shasum -a 256 -c Hello-Mini-0.10.0-macos-arm64.zip.sha256
```

There is no in-app automatic updater yet. GitHub Actions artifacts are ad-hoc-signed development builds; use GitHub Releases for the notarized download.

## Build from source

Install Xcode 27 (or a compatible Swift 6.4 toolchain, which needs macOS 26.6 or later), open it once to finish setup, and select its command-line tools. Then:

```sh
git clone https://github.com/emmettl/hellomini.git
cd hellomini
make check
make app CONFIGURATION=release
open "dist/Hello Mini.app"
```

The generated app is locally ad-hoc signed. You can copy `dist/Hello Mini.app` to Applications. Quit an older running copy before replacing it. Source builds need the development toolchain; the published download does not.

## First use

- Launch apps from desktop icons or **Option-Command-M**, then use arrows/initial letters and Return.
- Open Control Panel to choose a theme and enable or disable the extra silliness.
- Print Monitor starts without a configured project. Use **Projects…** to add GitHub or GitLab `owner/project` paths, then select an individual or combined queue. Configured GitHub Enterprise Server and GitLab Self-Managed origins are also supported; see [Print Monitor setup](USER_GUIDE.md#print-monitor). Public projects usually need no token; optional tokens are stored in Keychain.
- Chooser discovers nearby services only after Browse. macOS may request Local Network access.
- Finder and file import use normal macOS file access. Aquarium reads local activity only when enabled. Puzzle captures only Hello Mini's own window, without Screen Recording access.

## Updates and your data

Quit Hello Mini and replace the application bundle to update it. Settings and the Scrapbook library live outside the bundle and are retained. There is no automatic updater in this version.

Back up `~/Library/Application Support/HelloMini/Scrapbook/` as a whole; the index and image files belong together. Desktop layout, themes, effect choices, time zones, Finder location, and CI project preferences are stored in the app's macOS preferences. CI tokens are separate Keychain items under `HelloMini.CI`.

Moving the app to macOS Trash does not erase those saved preferences, tokens, or scraps. Use Print Monitor's **Forget token** if you want to remove a saved CI token. Wastebasket moves selected build caches to macOS Trash; it never empties Trash. The [user guide](USER_GUIDE.md) explains each app's storage and access behaviour in more detail.
