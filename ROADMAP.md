# Roadmap

Hello Mini's guiding principle is **quintessential idiocy**: useful little applications, period-looking interfaces, and modern capabilities that would have been utterly impossible on the original hardware. Silliness is part of the product, not an apology for it. Applications can sit anywhere on the stupid/useful axis; they do not all need a practical excuse.

These are directions, not dated commitments. All nine original roadmap applications now have working first versions, following desktop persistence and resizing. Further depth and proposed desk accessories are listed below.

## Applications

Each application should work as a small, coherent application while contributing its own particular idiocy. All nine below have initial implementations.

| Application | Useful purpose | Essential idiocy |
| --- | --- | --- |
| **Print Monitor** | Show CI jobs, queues, failures, and downloadable build artifacts. Support commonly used CI services through provider modules and per-user configuration. | Software is apparently being printed. Queued builds become print jobs, running builds churn through the printer, and failures jam it. |
| **Chooser** | Discover machines and services on the local network, then open connections such as SSH or screen sharing. | A tiny beige Macintosh confidently surveys modern infrastructure. |
| **Wastebasket** | Review and selectively clear build caches, DerivedData, and old artifacts, with a preview of what will be removed. | A basket that looks full after three crumpled pages somehow contains 140 GB. |
| **Scrapbook** | Keep a searchable shelf of snippets, screenshots, commands, and links. | Instant search through an implausibly capacious vintage scrapbook. |
| **Desk Calculator** | Provide unit conversions, programmer arithmetic, timestamp conversion, and potentially plotting. | An unassuming calculator can erupt into an optional GPU-rendered mathematical tantrum. |
| **Disk First Aid** | Explain disk usage, free space, and available storage health information. Start with inspection rather than repair. | A solemn little doctor examines the SSD and prescribes more disk space for builds. |
| **World Clock** | Show time zones, working hours, and the Mini's uptime; extend or reuse the existing Clock module where appropriate. | A tiny monochrome window contains a needlessly elaborate live 3D globe. |
| **Aquarium** | Offer an ambient view of machine activity, usable as a desk accessory and an After Dark–inspired screensaver. | CPU load changes the current, network traffic becomes bubbles, and completed builds feed the fish. Sometimes the fish are having a difficult afternoon. |
| **Puzzle** | Supply a pleasantly unnecessary sliding-tile puzzle. | The tiles contain a live view of the desktop. Almost no practical justification is required. |

Print Monitor now reads GitHub Actions and GitLab pipelines on public or configured self-hosted servers through separate provider modules, with up to 12 saved projects, combined and individual queues, saved branch/workflow filters, independent refresh errors and completion histories, optional Keychain tokens, on-demand job sheets with failed-step or failure-reason information, and links to job logs and build artifacts. More providers, server-side history searches, subpath installations, and artifact downloads inside the app remain future work. Successful builds can now feed Aquarium through an optional completion callback.

Chooser discovers advertised SSH, Screen Sharing, HTTP, and HTTPS services using Bonjour, with manual host entry and explicit connection opening. Wastebasket reviews known Xcode/SwiftPM caches and chosen projects' `.build` contents, then moves only reviewed selections to macOS Trash. Disk First Aid lists mounted volumes and reads available SMART information; it performs no repairs.

Desk Calculator includes expressions, exact 64-bit programmer arithmetic, unit and timestamp conversions, plotting, and an optional Metal Mandelbrot excursion. World Clock shares the Clock module, saves chosen time zones and weekday working hours, previews time offsets, and supplies a decorative Metal globe. Puzzle uses solvable shuffles and a live picture of Hello Mini's own window, with freeze and manual refresh controls.

Aquarium now has an optional **Reflect system activity** setting in Control Panel, a decorative mode, manual feeding, and a screensaver preview sharing the same Metal renderer. Print Monitor now feeds fish after new successful builds, with initial-history suppression and duplicate protection. Aquarium and Flying Toasters share a screensaver host with optional idle activation and saved Control Panel choices. Standalone macOS screensaver packaging remains undecided.

Scrapbook now keeps notes, commands, links, and image snapshots, with explicit paste/import, full-text and caption search, editing, copy, and recoverable archiving. Its local library survives relaunches. OCR and cloud sync are not part of this first version.

## Shared design commitments

- Keep applications in their own SwiftPM modules using `MiniCore` and shared themed controls. External plugins containing compiled code and assets remain a possible distribution model; the exact model is undecided.
- Express modern graphics through the selected theme's visual language, including the shipped System 7 and early Aqua themes.
- Put optional spectacle in **Control Panel → Playfulness**, with individual switches and the existing Extra silliness master switch. Keep useful information available when effects are disabled.
- Respect Reduce Motion and window visibility, and stop unnecessary rendering when an application is closed or inactive. Elaborate effects must not compromise solid window interaction.
- Preserve the distinction between real status and decorative storytelling: a printer jam may represent a failed build, but the actual failure details must remain accessible.

## Latest polish

- Fully covered graphics accessories pause; partially visible ones continue. Window geometry still saves only after a drag or resize.
- Keyboard launcher access, arrow-key Puzzle play, compact CI rows, and helpful empty states are implemented and checked at 720p.
- Successful CI builds feed Aquarium through an independent, toggleable connection. The first refresh establishes history; repeat polls do not produce repeat meals.

## Next priorities

- Finish release validation, including longer sessions, sleep/wake, display changes, and saved-state upgrades; publish once signing is available.
- Validate Print Monitor against users' self-hosted installations, then consider server-side history searches and in-app artifact downloads. Saved projects, combined queues, recent-build filters, job/failure details, and configurable server origins are implemented.
- Validate the 0.2.0 desktop additions below, especially live CI retries, system mute, timer sleep/wake, and the macOS screenshot shortcut interaction.
- System 7 and early Aqua are implemented as independent theme modules. Purist mode offers a fixed 512 × 384 desktop across themes. Refine era-specific controls as the shared framework grows.
- Add deliberate Finder file operations and Scrapbook export/import.
- Decide the external binary plugin model when contributor needs are clearer.

The first screensaver pass is now implemented: shared host, Aquarium, original Metal flying toasters, opt-in idle activation, and Control Panel settings. Additional effects can register through the same host.

## Implemented for 0.2.0 — awaiting release validation

- **System sounds:** Original synthesised startup, jam, feeding, Wastebasket, and alarm cues share one Playfulness switch and normal system output. CI monitoring now belongs to the host and continues with Print Monitor closed. Initial history and repeat polls do not replay alerts.
- **Menu bar status strip:** A printer glyph reflects all saved projects independently of the visible queue filters; a thermometer reports thermal state. Aqua dock tiles share attention badges. Status remains readable with effects disabled and in Purist mode.
- **Clear the paper jam:** A themed dialog retries GitHub failed jobs and their dependents, or GitLab failed/cancelled pipeline jobs. **Copies** defaults to one and is capped at three. Subsequent copies require observing the previous attempt become active and fail; uncertainty stops the sequence. This is Print Monitor's only write action.
- **Clipboard and desktop snapshots:** **Edit → Show Clipboard** reads text or images on demand. **File → Capture Desktop to Scrapbook** saves Hello Mini's own desktop through `DesktopPicture`, without changing the clipboard. Command-Shift-3 is wired locally, but the macOS screenshot shortcut may take precedence.
- **Special menu:** Empty Wastebasket opens the existing reviewed cache-cleanup flow; Restart relaunches Hello Mini; Shut Down quits it.
- **Menu item blink:** System 7 commands flash three times before activation, with Playfulness and Reduce Motion gates.
- **Key Caps:** A US keyboard with shifted characters, a curated Unicode/emoji palette, click-to-copy, and the native macOS character viewer for the wider character set. Live physical-key highlighting and other keyboard layouts remain future depth.
- **Alarm Clock:** Saved timers, explicit 25-minute focus sessions and 5-minute breaks, sound, and a flashing menu bar alarm. Sleep counts toward the deadline; overdue timers fire on wake or relaunch, and already-ringing alarms restore without replaying sound. Reduced motion uses a steady indicator.
- **Find File:** Spotlight file-name search with a little dog, selectable folder scope, the first 200 results, and Open/Reveal actions. Finder supplies a search button and Command-F. Indexing and access limitations are explained in the window.
- **Desktop pattern editor:** Saved 8 × 8 ink/paper patterns in Control Panel → Appearance, applied immediately with clear/reset controls.
- **Finder labels:** Seven colour labels update the matching named macOS tags and legacy label colour, retaining unrelated tags. Broader file operations remain future work.
- **Aqua dock magnification and launch bounce:** Hover enlargement and a finite two-hop cue for newly opened apps respect Playfulness and Reduce Motion. **Genie minimisation remains future work**, with focus, geometry, and restoration reliability as prerequisites.
- **System 7 Balloon Help:** A saved Help-menu toggle enables shared hover explanations above the desktop; native help and accessibility hints remain available.

## Other continuing directions

- **Themes:** System 7 and Mac OS X 10.0–inspired Aqua are available, including pinstripes, gel controls, original smooth icons, working Aqua traffic lights for close, minimise, and zoom, and a dock with running indicators and minimised-window restoration. More era-specific controls can follow without duplicating application behavior.
- **More spectacle:** Flying Toasters is implemented. Living dither, Impossible instruments, Physical windows, and Depth behind glass remain future effects, all optional through Playfulness.
- **Distribution:** MIT is selected; local signing/notarization tooling and release documentation are ready. Supply a Developer ID Application identity and notarization profile, validate the downloadable candidate, then publish the first GitHub release and evaluate Homebrew. Explicit installation on the Mini remains separate from its working private build pipeline.
- **Compatibility:** macOS 26 remains the baseline; consider macOS 15 only if it does not hinder selective adoption of newer features.

See the [README](README.md) for what works today and [CI documentation](docs/CI.md) for the existing build pipelines.
