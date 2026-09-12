# Roadmap

Hello Mini's guiding principle is **quintessential idiocy**: useful little applications, period-looking interfaces, and modern capabilities that would have been utterly impossible on the original hardware. Silliness is part of the product, not an apology for it. Applications can sit anywhere on the stupid/useful axis; they do not all need a practical excuse.

These are directions, not dated commitments. All nine applications now have working first versions, following desktop persistence and resizing. Further depth is listed below.

## Applications

All nine belong on the roadmap. Each should work as a small, coherent application while contributing its own particular idiocy. All nine have initial implementations.

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

Print Monitor now reads GitHub Actions and GitLab.com pipelines through separate provider modules, with per-user project configuration, optional Keychain tokens, and links to build pages for logs and artifacts. More providers, self-hosted service URLs, job-level details, and artifact downloads inside the app remain future work. Successful builds can now feed Aquarium through an optional completion callback.

Chooser discovers advertised SSH, Screen Sharing, HTTP, and HTTPS services using Bonjour, with manual host entry and explicit connection opening. Wastebasket reviews known Xcode/SwiftPM caches and chosen projects' `.build` contents, then moves only reviewed selections to macOS Trash. Disk First Aid lists mounted volumes and reads available SMART information; it performs no repairs.

Desk Calculator includes expressions, exact 64-bit programmer arithmetic, unit and timestamp conversions, plotting, and an optional Metal Mandelbrot excursion. World Clock shares the Clock module, saves chosen time zones and weekday working hours, previews time offsets, and supplies a decorative Metal globe. Puzzle uses solvable shuffles and a live picture of Hello Mini's own window, with freeze and manual refresh controls.

Aquarium now has an optional **Reflect system activity** setting in Control Panel, a decorative mode, manual feeding, and a screensaver preview sharing the same Metal renderer. Print Monitor now feeds fish after new successful builds, with initial-history suppression and duplicate protection. Aquarium and Flying Toasters share a screensaver host with optional idle activation and saved Control Panel choices. Standalone macOS screensaver packaging remains undecided.

Scrapbook now keeps notes, commands, links, and image snapshots, with explicit paste/import, full-text and caption search, editing, copy, and recoverable archiving. Its local library survives relaunches. OCR and cloud sync are not part of this first version.

## Shared design commitments

- Keep applications in their own SwiftPM modules using `MiniCore` and shared themed controls. External plugins containing compiled code and assets remain a possible distribution model; the exact model is undecided.
- Express modern graphics through the selected theme's visual language, including future System 7 and early Aqua designs.
- Put optional spectacle in **Control Panel → Playfulness**, with individual switches and the existing Extra silliness master switch. Keep useful information available when effects are disabled.
- Respect Reduce Motion and window visibility, and stop unnecessary rendering when an application is closed or inactive. Elaborate effects must not compromise solid window interaction.
- Preserve the distinction between real status and decorative storytelling: a printer jam may represent a failed build, but the actual failure details must remain accessible.

## Latest polish

- Fully covered graphics accessories pause; partially visible ones continue. Window geometry still saves only after a drag or resize.
- Keyboard launcher access, arrow-key Puzzle play, compact CI rows, and helpful empty states are implemented and checked at 720p.
- Successful CI builds feed Aquarium through an independent, toggleable connection. The first refresh establishes history; repeat polls do not produce repeat meals.

## Next priorities

- Finish release validation, including longer sessions, sleep/wake, display changes, and saved-state upgrades; publish once signing is available.
- Deepen Print Monitor with saved projects, job/failure details, and self-hosted GitHub/GitLab endpoints.
- Build System 7 as the first distinct-era theme, then early Aqua, exercising the shared theme framework.
- Add deliberate Finder file operations and Scrapbook export/import.
- Decide the external binary plugin model when contributor needs are clearer.

The first screensaver pass is now implemented: shared host, Aquarium, original Metal flying toasters, opt-in idle activation, and Control Panel settings. Additional effects can register through the same host.

## Other continuing directions

- **Themes:** System 7 and Mac OS X 10.0–era Aqua, including its pinstripes.
- **More spectacle:** Flying Toasters is implemented. Living dither, Impossible instruments, Physical windows, and Depth behind glass remain future effects, all optional through Playfulness.
- **Distribution:** MIT is selected; local signing/notarization tooling and release documentation are ready. Supply a Developer ID Application identity and notarization profile, validate the downloadable candidate, then publish the first GitHub release and evaluate Homebrew. Explicit installation on the Mini remains separate from its working private build pipeline.
- **Compatibility:** macOS 26 remains the baseline; consider macOS 15 only if it does not hinder selective adoption of newer features.

See the [README](README.md) for what works today and [CI documentation](docs/CI.md) for the existing build pipelines.
