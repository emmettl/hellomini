# Changelog

## 0.10.0 — 2026-10-18

- **Chooser:** Save up to 40 service/host/port destinations, skip duplicates, forget addresses and connect explicitly through macOS handlers; stale discovery callbacks cannot repopulate a stopped search.
- **Impossible instruments:** Opt-in CPU dial and decorative particles in Activity Monitor, retaining real numeric readings and pausing with visibility, scene, display sleep and Reduce Motion controls.
- **Display polish:** Saved 1.5× comparison scale alongside default 2×, with unchanged Purist dimensions; responsive shared form widths for cramped sheets.

- Fit Print Monitor's Projects sheet to the logical desktop so Purist mode keeps its actions reachable.
- Keep the native window on screen after display-resolution changes, full-screen exit and restoration from Purist mode.
- Record physical Wokyis resolution, display-sleep and DarkWake recovery checks, with explicit full-sleep and soak limitations.

## 0.9.0 — 2026-10-18

- **Finder transfers:** Bounded streaming copies with byte progress and cancellation, exclusive staged commits, source-change checks, metadata preservation and rejection of special files. Reviewed Move To performs an atomic move within one volume; cross-volume moves leave the source intact and require macOS Finder.
- **Portable desks:** Export/import desktop presets with window-map review, duplicate skipping and separate identities/names for conflicts. Imports retain existing desks and open documents; unavailable themes are identified before applying.
- **Living dither:** An opt-in themed field of moving ink dots around windows. Reduce Motion gives a static field; inactive, obscured and sleeping desktops pause animation.
- **Recovery and validation:** New layout backups record dates and show clearer restore/export guidance. Regression tests cover transfer cancellation/cleanup, exclusive moves, preset portability and animation lifecycle gates. Live GitLab testing is unavailable because no test instance is configured; extended hardware soak and comprehensive VoiceOver coverage remain continuing work.

## Distribution update — 2026-10-18

- Added the existing signed, notarized 0.8.0 release to `emmettl/tap/hellomini`; no new app binary or version was released.
- Added checksum/manifest-verified tap updates to the release process, plus Homebrew install/update instructions and the website command. Strict online audit, style and isolated installation checks passed.

## 0.8.0 — 2026-10-18

- **Print Archive:** Browse up to 50 pages of server-side build history per project, with exact branch search, job inspection, artifact access, and links to earlier GitHub run attempts. Archive browsing does not replay build alerts or change live status.
- **Artifact downloads:** Paginated GitHub run artifacts and GitLab job archives, reviewed new-file destinations, byte progress, cancellation, a 512 MB limit, ZIP-header checks and quarantine metadata. Cross-origin redirects strip credentials; HTTP redirects are refused. Archives are never opened or extracted automatically.
- **Finder operations:** Reviewed New Folder, Rename and Copy To actions. Destinations are never replaced; copying stages output before commit, retains symlinks, and limits collections to 512 MB / 10,000 entries.
- **Desktop previews and recovery:** Theme/window-map thumbnails for saved presets; inspect, export original bytes, and deliberately restore saved desktop backups while retaining open documents.
- **Validation:** Deterministic probe deadlines/DNS/replacement/stale-event tests, primary-control geometry checks, provider fixtures, artifact redirect/commit checks and opt-in live GitHub history/download tests.

## 0.7.0 — 2026-10-18

- **Network:** A modem-style accessory with system connection status, active interface addresses, explicit TCP reachability calls, setup times, cancellation, five-second deadlines and a bounded session log. Optional operator commentary lives in Playfulness.
- **Finder:** Read-only Get Info, bounded text and image previews, and up to 20 saved favourite folders.
- **Saved desktop recovery:** Preserve corrupt or newer sessions until explicit recovery; keep the original as a backup and resume saving with default geometry. Legacy sessions continue to load.
- **Scrapbook reliability:** Event-driven OCR scheduling, cancellation on disappearance, stale-result protection, and a visible warning when searchable picture text could not be saved.
- **Validation and distribution:** Rendered accessory layout checks across six themes, opt-in one-day CI development artifacts, and current website/user-guide information. Public releases continue to ship signed and notarized downloads separately.

## 0.6.0 — 2026-10-18

- **MiniPaint:** A monochrome 320 × 200 drawing accessory with pencil, eraser, patterned flood fill, rectangular selection/move, bounded undo/redo, local autosave, PNG export, and Send to Scrapbook. Includes an original icon in pixel and Aqua styles.
- **Desktop presets:** Save named themes, patterns, display modes and window arrangements from View → Desktop Presets. Switching minimises other open windows while retaining their contents. Presets can be replaced or deleted without modifying application data.
- **Scrapbook transfers:** Export one scrap as text or PNG, export the visible filtered scraps as a portable collection, or back up the whole library including archived scraps and pictures. Imports preview additions, skip identical content and preserve identifier conflicts as separate scraps; existing entries are never replaced.

- **Creative round trip:** Open Scrapbook pictures in MiniPaint with a monochrome preview, aspect-preserving fit and Undo. Apply a selected drawing region as an 8 × 8 desktop pattern.
- **Example scraps:** Explicitly add original fish artwork, a checksum command, and questionable encouragement from the Scrapbook menu. Existing scraps are retained.

## [0.5.0](https://github.com/emmettl/hellomini/releases/tag/v0.5.0) — 2026-10-01

- **Communications:** A vintage receiving station for Prometheus-compatible telemetry, with configurable channels, status lamps, an hour of strip-chart history, and a session log. OpenTelemetry metrics can be viewed through a compatible backend.
- Background polling, explicit stale/missing evidence, read-only queries, per-server Keychain tokens, optional loss/recovery sounds, Test Lamps, and a clearly labelled simulation.
- A MotionStudies preset and read-only observer exporter example preserve original observation timestamps. Live monitoring requires a separately configured exporter and metrics backend; no production connection is bundled.
- Communications adapts to tiny-screen and Purist desktops; instrument motion respects Playfulness, Reduce Motion, and visibility.

- **Ambient animation:** Aquarium, Teapot, the World Clock globe, Desk Calculator's Mandelbrot, Print Monitor's paper, and live Puzzle tiles keep moving while they are on screen, even when another app or another Mac through Universal Control has focus. Metal views draw at half their frame rate while Hello Mini is in the background and pause only when their window is hidden, covered, or on a sleeping display.
- Long-running tanks and scenes no longer freeze after about twelve days. Their animation clocks wrap once a day.

## [0.4.0](https://github.com/emmettl/hellomini/releases/tag/v0.4.0) — 2026-09-15

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
