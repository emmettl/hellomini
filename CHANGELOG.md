# Changelog

## 0.4.0 — release candidate

- Development moves to Xcode 27 and Swift 6.4. Public CI uses GitHub's `xcode-27` runner image, and the toolchain check accepts any Xcode 27 release. The Mac Mini runner needs Xcode 27 at `/Applications/Xcode.app`.
- App bundling reads resource bundles from Swift Build, SwiftPM 6.4's default build engine, as well as the older native layout.
- **Tiny-screen fixes from Wokyis testing.** Control Panel theme choices now respond where they are drawn at 2×. The theme strip is pure SwiftUI, with a themed, always-visible scrollbar and smaller cards in tiny-screen mode.
- Every bundled app now fits tiny-screen and Purist desktops in every theme. Crowded toolbars shorten or wrap, secondary notes move into help, and long content scrolls inside the window instead of hiding toolbars. Activity Monitor switches to a compact summary and keeps its process list visible.
- The Aqua dock uses a slimmer shelf on desktops shorter than 480 points, which covers tiny-screen and Purist modes.
- **Platinum**: a Mac OS 8 homage theme with bevelled chrome, ridged title bars, heavy condensed type, and window shade. Collapse a window from its title bar box, a double-click, or the Window menu.
- **Genie minimise** pours Aqua windows into the dock and back out, with a Playfulness switch and Reduce Motion support.
- **Scrapbook** reads text in pictures on this Mac with Vision and includes it in search. **Scrapbook Slideshow** joins the screensavers.
- **Fish remember builds**: green streaks grow the fish and bring a tenth; a failure sends them sulking to the gravel.
- **Talking Moose**, off by default, comments out loud on newly passed and failed builds.
- The app still targets macOS 26; nothing in this change requires macOS 27 at runtime.

## [0.3.0](https://github.com/emmettl/hellomini/releases/tag/v0.3.0) — 2026-09-13

- **Tiny-screen mode**: a saved 2× presentation setting across themes, available in Control Panel and both View menus. Enlarges the desktop, startup, screensavers, and custom sheet content; mutually exclusive with Purist mode.
- Responsive Finder, Print Monitor, and Control Panel layouts for the smaller logical workspace. Other oversized app content remains accessible through scrolling. Physical Wokyis legibility testing is deferred until the device arrives; the broader workflow audit remains follow-up work.
- Rounded screen corners and an inset bevel are rendered inside the app so the edge treatment survives full-screen presentation.

## [0.2.0](https://github.com/emmettl/hellomini/releases/tag/v0.2.0) — 2026-09-13

- Original synthesised startup, paper-jam, feeding, Wastebasket, and alarm sounds, controlled by one Playfulness switch and normal system volume/mute.
- Background CI polling while Hello Mini runs, a menu bar printer/thermal strip, and Aqua dock attention badges. Historical and duplicate build completions stay quiet.
- **Clear jam…** for GitHub Actions and GitLab, with one to three sequential retry copies, token permission guidance, stop controls, and conservative handling of uncertain responses.
- **Edit → Show Clipboard**, and **File → Capture Desktop to Scrapbook** with a Command-Shift-3 shortcut when macOS delivers it to the app. The macOS screenshot shortcut may take precedence; the menu command is always available.
- **Special** menu with reviewed Wastebasket cleanup, Hello Mini relaunch, and quit; optional three-flash System 7 menu feedback.
- **Key Caps** with a US keyboard, shifted characters, a Unicode/emoji palette, click-to-copy, and access to the macOS character viewer.
- **Alarm Clock** with saved timers, 25-minute focus sessions, 5-minute breaks, and a menu bar alarm that survives closed accessory windows. Overdue timers fire on wake or next launch; sessions advance explicitly.
- **Find File** with Spotlight file-name search, a tiny dog, folder scope, and Open/Reveal actions; Finder supplies a search button and Command-F.
- A saved **8 × 8 desktop pattern editor** in Control Panel, and Finder colour labels that update named macOS tags while preserving unrelated tags.
- Optional Aqua dock magnification, a brief two-hop launch bounce, and System 7 **Balloon Help**, with native help and accessibility hints retained.

Requires Apple silicon and macOS 26 or later. Genie minimisation and additional keyboard layouts remain on the roadmap.

## [0.1.0](https://github.com/emmettl/hellomini/releases/tag/v0.1.0) — 2026-09-13

The first complete little desktop, available as a Developer ID-signed and Apple-notarized ZIP from [GitHub Releases](https://github.com/emmettl/hellomini/releases/tag/v0.1.0).

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

Requires Apple silicon and macOS 26 or later. Designed around 1280 × 720, with a normal minimum window size of 960 × 600 and optional 512 × 384 Purist mode. Source builds require Swift 6.3+. In-app artifact downloads, standalone macOS screensaver packaging, and external plugin loading remain future work.
