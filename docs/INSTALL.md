# Installing Hello Mini

Hello Mini's first release candidate targets **Apple silicon and macOS 26**. The desktop is designed for 1280 × 720 and supports a minimum window size of 960 × 600.

## Build from source today

Install Xcode 26.6 (or a compatible Swift 6.3 toolchain), open it once to finish setup, and select its command-line tools. Then:

```sh
git clone https://github.com/emmettl/hellomini.git
cd hellomini
make check
make app CONFIGURATION=release
open "dist/Hello Mini.app"
```

The generated app is locally ad-hoc signed. You can copy `dist/Hello Mini.app` to Applications. Quit an older running copy before replacing it. Source builds need Xcode; a future notarized binary download will not.

There is no published notarized download or Homebrew cask yet. The temporary ZIPs on GitHub Actions are development artifacts, not the public installer. A public release will be linked from the [releases page](https://github.com/emmettl/hellomini/releases) once signed builds are available. Its installation instructions will be: expand the versioned ZIP, move Hello Mini to Applications, and open it normally.

## First use

- Launch apps from desktop icons or **Option-Command-M**, then use arrows/initial letters and Return.
- Open Control Panel to choose a theme and enable or disable the extra silliness.
- Print Monitor starts without a configured project. Enter a GitHub or GitLab.com `owner/project` path and choose Load. Public projects usually need no token; optional tokens are stored in Keychain.
- Chooser discovers nearby services only after Browse. macOS may request Local Network access.
- Finder and file import use normal macOS file access. Aquarium reads local activity only when enabled. Puzzle captures only Hello Mini's own window, without Screen Recording access.

## Updates and your data

Quit Hello Mini and replace the application bundle to update it. Settings and the Scrapbook library live outside the bundle and are retained. There is no automatic updater in this version.

Back up `~/Library/Application Support/HelloMini/Scrapbook/` as a whole; the index and image files belong together. Desktop layout, themes, effect choices, time zones, Finder location, and CI project preferences are stored in the app's macOS preferences. CI tokens are separate Keychain items under `HelloMini.CI`.

Moving the app to macOS Trash does not erase those saved preferences, tokens, or scraps. Use Print Monitor's **Forget token** if you want to remove a saved CI token. Wastebasket moves selected build caches to macOS Trash; it never empties Trash. The README explains each app's storage and access behaviour in more detail.
