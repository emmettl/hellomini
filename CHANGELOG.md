# Changelog

## 0.2.0 — in development

- Original synthesised startup, paper-jam, feeding, Wastebasket, and alarm sounds, controlled by one Playfulness switch and normal system volume/mute.
- Background CI polling while Hello Mini runs, a menu bar printer/thermal strip, and Aqua dock attention badges. Historical and duplicate build completions stay quiet.
- **Clear jam…** for GitHub Actions and GitLab, with one to three sequential retry copies, token permission guidance, stop controls, and conservative handling of uncertain responses.
- **Edit → Show Clipboard**, and **File → Capture Desktop to Scrapbook** with a Command-Shift-3 shortcut when macOS delivers it to the app. The macOS screenshot shortcut may take precedence; the menu command is always available.
- **Special** menu with reviewed Wastebasket cleanup, Hello Mini relaunch, and quit; optional three-flash System 7 menu feedback.
- **Key Caps** with a US keyboard, shifted characters, a Unicode/emoji palette, click-to-copy, and access to the macOS character viewer.
- **Alarm Clock** with saved timers, 25-minute focus sessions, 5-minute breaks, and a menu bar alarm that survives closed accessory windows. Overdue timers fire on wake or next launch; sessions advance explicitly.
- **Find File** with Spotlight file-name search, a tiny dog, folder scope, and Open/Reveal actions; Finder supplies a search button and Command-F.
- A saved **8 × 8 desktop pattern editor** in Control Panel, and Finder colour labels that update named macOS tags while preserving unrelated tags.
- Optional Aqua dock magnification and System 7 **Balloon Help**, with native help and accessibility hints retained.

Genie minimisation remains on the roadmap. This is a local development build, not a signed public release. Live CI writes and extended sleep/wake testing remain release-validation work.

## 0.1.0 — release candidate

The first complete little desktop. This candidate is being prepared; no signed public binary release has been published yet.

- A Macintosh startup homage, themed desktop menus, pixel icons, and saved, resizable windows. Optional Purist mode fixes the logical desktop at 512 × 384, with compact menus, scrollable oversized app content, and restoration of the larger window.
- Finder, Activity Monitor, Clock, and Control Panel with Classic, Paper, Midnight, System 7, and Aqua themes. Aqua adds pinstripes, gel controls, smooth colour icons, blue wave wallpaper, and working red/yellow/green close, minimise, and zoom buttons. Minimised and zoomed states survive relaunch, and Window menu actions work across themes. Aqua also includes a translucent dock with running indicators, app launching, minimised-window tiles, keyboard navigation, and reserved window space.
- Aquarium, Utah Teapot, and a decorative World Clock globe rendered with Metal in the selected theme's palette.
- Scrapbook for local notes, commands, links, and image snapshots.
- Desk Calculator with expressions, exact programmer arithmetic, units, timestamps, plots, and unreasonable mathematics.
- A sliding Puzzle made from the live desktop, playable with the keyboard.
- Chooser for Bonjour services, Disk First Aid for read-only volume inspection, and Wastebasket for reviewed cache cleanup through macOS Trash.
- Print Monitor for GitHub Actions and GitLab, including self-hosted servers, with saved projects, combined queues, branch/workflow filters, and per-project errors and refresh history, and job sheets with failed steps, failure reasons, and direct log links. Successful builds can feed Aquarium; repeated polls and old history do not.
- Aquarium and original Metal Flying Toasters screensavers with shared presentation, saved selection, opt-in idle timing, and input dismissal.
- Optional spectacle switches, Reduce Motion support, and pausing for fully covered graphics windows.
- Independent SwiftPM application modules and shared theme and CI-provider contracts.

Requires Apple silicon, macOS 26, and a 960 × 600 or larger desktop; designed around 1280 × 720. Source builds require Swift 6.3. Public binary signing and notarization are pending. In-app artifact downloads, standalone macOS screensaver packaging, and external plugin loading remain future work.
