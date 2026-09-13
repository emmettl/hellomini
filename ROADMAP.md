# Roadmap

Hello Mini's guiding principle is **quintessential idiocy**: useful little applications, period-looking interfaces, and modern capabilities that would have been utterly impossible on the original hardware. Silliness is part of the product, not an apology for it. Applications can sit anywhere on the stupid/useful axis; they do not all need a practical excuse.

Version [0.2.0](https://github.com/emmettl/hellomini/releases/tag/v0.2.0) adds the desktop accessories and polish listed below to the signed, notarized release line. The [website](https://hellomini.app) is live. All nine original roadmap applications have working first versions. **0.3.0 will focus on tiny-screen mode:** making the whole interface readable on a physically small 720p display at normal desk distance. This is planned work, with no dated commitment.

## Applications

Each application should work as a small, coherent application while contributing its own particular idiocy. All nine below have initial implementations.

| Application | Useful purpose | Essential idiocy |
| --- | --- | --- |
| **Print Monitor** | Show CI jobs, queues, failures, and links to build artifacts. Support commonly used CI services through provider modules and per-user configuration. | Software is apparently being printed. Queued builds become print jobs, running builds churn through the printer, and failures jam it. |
| **Chooser** | Discover machines and services on the local network, then open connections such as SSH or screen sharing. | A tiny beige Macintosh confidently surveys modern infrastructure. |
| **Wastebasket** | Review and selectively clear build caches, DerivedData, and old artifacts, with a preview of what will be removed. | A basket that looks full after three crumpled pages somehow contains 140 GB. |
| **Scrapbook** | Keep a searchable shelf of snippets, screenshots, commands, and links. | Instant search through an implausibly capacious vintage scrapbook. |
| **Desk Calculator** | Provide unit conversions, programmer arithmetic, timestamp conversion, and potentially plotting. | An unassuming calculator can erupt into an optional GPU-rendered mathematical tantrum. |
| **Disk First Aid** | Explain disk usage, free space, and available storage health information. Start with inspection rather than repair. | A solemn little doctor examines the SSD and prescribes more disk space for builds. |
| **World Clock** | Show time zones, working hours, and the Mini's uptime; extend or reuse the existing Clock module where appropriate. | A tiny monochrome window contains a needlessly elaborate live 3D globe. |
| **Aquarium** | Offer an ambient view of machine activity, usable as a desk accessory and an After Dark–inspired screensaver. | CPU load changes the current, network traffic becomes bubbles, and completed builds feed the fish. Sometimes the fish are having a difficult afternoon. |
| **Puzzle** | Supply a pleasantly unnecessary sliding-tile puzzle. | The tiles contain a live view of the desktop. Almost no practical justification is required. |

The [user guide](docs/USER_GUIDE.md) describes shipped behaviour, configuration, and limits. In-app artifact downloads, additional CI providers, standalone macOS screensaver packaging, Scrapbook OCR, and cloud sync are not included in 0.2.0.

## Shared design commitments

- Keep applications in their own SwiftPM modules using `MiniCore` and shared themed controls. External plugins containing compiled code and assets remain a possible distribution model; the exact model is undecided.
- Express modern graphics through the selected theme's visual language, including the shipped System 7 and early Aqua themes.
- Put optional spectacle in **Control Panel → Playfulness**, with individual switches and the existing Extra silliness master switch. Keep useful information available when effects are disabled.
- Respect Reduce Motion and window visibility, and stop unnecessary rendering when an application is closed or inactive. Elaborate effects must not compromise solid window interaction.
- Preserve the distinction between real status and decorative storytelling: a printer jam may represent a failed build, but the actual failure details must remain accessible.
- Treat legibility as a shared display concern across every theme. Enlarge text, controls, icons, and interaction targets together; adapt crowded layouts without shrinking essential information again.

## Shipped in 0.1.0

- Fully covered graphics accessories pause; partially visible ones continue. Window geometry still saves only after a drag or resize.
- Keyboard launcher access, arrow-key Puzzle play, compact CI rows, and helpful empty states are implemented and checked at 720p.
- Successful CI builds feed Aquarium through an independent, toggleable connection. The first refresh establishes history; repeat polls do not produce repeat meals.

## Planned for 0.3.0 — Tiny-screen mode

A layout fitting 1280 × 720 does not establish that it is readable on the Wokyis at normal desk distance. Tiny-screen mode is the next release's primary feature. The [scope and design](docs/TINY_SCREEN_MODE.md) track architecture, tradeoffs, implementation progress, and remaining release checks. The first 2× implementation is available in source; physical-display validation remains outstanding.

- **One setting, every theme:** Add a saved Tiny-screen mode control in Control Panel → Appearance and the View menu. Start with 2× enlargement for evaluation, with 1.5× as a secondary candidate. Choose the shipping default through physical-display testing.
- **Enlarge the complete interface:** Cover text, window chrome, buttons, icons, menus, status indicators, help, and application content. Keep the display filled while giving applications a smaller logical workspace.
- **Preserve bevelled edges in full screen:** Retain the desktop's bevelled edge treatment when entering full screen, including in tiny-screen mode.
- **Make that workspace usable:** Reflow dense toolbars and lists, provide reachable menu/launcher overflow, and keep all essential actions accessible. Prioritise Control Panel, Print Monitor, and Finder, then audit every bundled app and both launcher styles.
- **Keep theme and display responsibilities clear:** The host owns presentation scale and coordinates; the shared UI framework exposes layout context and semantic metrics where needed. Themes retain their visual identity and must honour that shared contract.
- **Preserve state and recovery:** Switching modes keeps open apps, drafts, focus, and saved window placements. Purist mode retains its fixed 512 × 384 behaviour; the two modes are mutually exclusive. Turning tiny-screen mode off must remain easy.
- **Validate on the hardware:** Verify reading and interaction on the physical Wokyis at a recorded normal viewing distance, alongside automated geometry/state checks and visual checks across all five themes. A 720p screenshot alone is insufficient.

Other new feature directions remain secondary to completing this usability work.

## Other next priorities

- Continue longer-session, sleep/wake, display-change, and saved-state upgrade testing for subsequent releases. The signed 0.1.0 download has been tested on the physical Mini.
- Validate Print Monitor against users' self-hosted installations, then consider server-side history searches and in-app artifact downloads. Saved projects, combined queues, recent-build filters, job/failure details, and configurable server origins are implemented.
- Continue live CI retry validation across providers and self-hosted installations, including token permissions and long-running pipelines.
- System 7 and early Aqua are implemented as independent theme modules. Purist mode offers a fixed 512 × 384 desktop across themes. Refine era-specific controls as the shared framework grows.
- Add deliberate Finder file operations and Scrapbook export/import.
- Decide the external binary plugin model when contributor needs are clearer.

## Shipped in 0.2.0

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
- **Distribution:** The MIT-licensed release is available as a signed, notarized GitHub download, linked from hellomini.app. Evaluate a Homebrew cask next; App Store distribution remains undecided. CI continues to produce development artifacts separately from public releases.
- **Compatibility:** macOS 26 remains the baseline; consider macOS 15 only if it does not hinder selective adoption of newer features.

See the [user guide](docs/USER_GUIDE.md) for what works today and [CI documentation](docs/CI.md) for the existing build pipelines.
