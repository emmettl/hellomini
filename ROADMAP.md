# Roadmap

Hello Mini's guiding principle is **quintessential idiocy**: useful little applications, period-looking interfaces, and modern capabilities that would have been utterly impossible on the original hardware. Silliness is part of the product, not an apology for it. Applications can sit anywhere on the stupid/useful axis; they do not all need a practical excuse.

Version [0.1.0](https://github.com/emmettl/hellomini/releases/tag/v0.1.0) is published, signed, and notarized. The [website](https://hellomini.app) is live. All nine original roadmap applications have working first versions. Everything under Next priorities and the proposal sections below is future work, not a claim about the released app; there are no dated commitments.

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

The [user guide](docs/USER_GUIDE.md) describes shipped behaviour, configuration, and limits. In-app artifact downloads, additional CI providers, standalone macOS screensaver packaging, Scrapbook OCR, and cloud sync are not included in 0.1.0.

## Shared design commitments

- Keep applications in their own SwiftPM modules using `MiniCore` and shared themed controls. External plugins containing compiled code and assets remain a possible distribution model; the exact model is undecided.
- Express modern graphics through the selected theme's visual language, including the shipped System 7 and early Aqua themes.
- Put optional spectacle in **Control Panel → Playfulness**, with individual switches and the existing Extra silliness master switch. Keep useful information available when effects are disabled.
- Respect Reduce Motion and window visibility, and stop unnecessary rendering when an application is closed or inactive. Elaborate effects must not compromise solid window interaction.
- Preserve the distinction between real status and decorative storytelling: a printer jam may represent a failed build, but the actual failure details must remain accessible.

## Shipped in 0.1.0

- Fully covered graphics accessories pause; partially visible ones continue. Window geometry still saves only after a drag or resize.
- Keyboard launcher access, arrow-key Puzzle play, compact CI rows, and helpful empty states are implemented and checked at 720p.
- Successful CI builds feed Aquarium through an independent, toggleable connection. The first refresh establishes history; repeat polls do not produce repeat meals.

## Next priorities

- Continue longer-session, sleep/wake, display-change, and saved-state upgrade testing for subsequent releases. The signed 0.1.0 download has been tested on the physical Mini.
- Validate Print Monitor against users' self-hosted installations, then consider server-side history searches and in-app artifact downloads. Saved projects, combined queues, recent-build filters, job/failure details, and configurable server origins are implemented.
- Start the next desktop pass with shared system sounds and a menu bar status strip, then connect Alarm Clock and CI retry feedback to that plumbing. Clipboard viewing, desktop capture into Scrapbook, and the Special menu are useful companion additions.
- System 7 and early Aqua are implemented as independent theme modules. Purist mode offers a fixed 512 × 384 desktop across themes. Refine era-specific controls as the shared framework grows.
- Add deliberate Finder file operations and Scrapbook export/import.
- Decide the external binary plugin model when contributor needs are clearer.

## Cheap wins that fit existing plumbing

These are proposed additions, not shipped features or fixed effort estimates.

- **System sounds:** Original synthesised alerts for a paper jam, fish being fed, and Wastebasket emptying, plus a startup chime under the boot homage. Use one System sounds switch in Control Panel → Playfulness, governed by Extra silliness and respecting system mute. A newly observed CI failure should be audible while Hello Mini is running even when Print Monitor is closed; initial history and repeat polls must not replay alerts. Reuse completion tracking and the Aquarium feeding connection.
- **Menu bar status strip:** A tiny printer glyph beside the clock jams when any saved project's latest build fails. Add a thermometer driven by system thermal state, with a readable state description rather than an invented temperature. The Aqua Print Monitor dock tile can show the same jam badge. Keep status understandable without sound or animation, and fit the strip into compact and Purist layouts.
- **Clear the paper jam:** Add an explicit retry action for failed GitHub Actions jobs and GitLab pipeline jobs, presented in a themed dialog with a **Copies** field meaning retry count. Keep this Print Monitor's only planned write action. Extend the currently read-only provider interface, verify each provider's retry semantics and required token permissions, and define bounded, sequential retry behaviour with a default of one. Show the actual project, failed run, and retry result beneath the stationery joke.
- **Show Clipboard and desktop snapshots:** Add **Edit → Show Clipboard** as an on-demand viewer, and capture Hello Mini's desktop directly into Scrapbook through the `DesktopPicture` capture already used by Puzzle. Target **Command-Shift-3** while Hello Mini is active; check interaction with the macOS screenshot shortcut and provide a discoverable menu command. Capture Hello Mini's own desktop and reuse Scrapbook's existing image storage.
- **Special menu:** Add **Empty Wastebasket**, **Restart**, and **Shut Down**. Empty Wastebasket should reuse the existing review and move-to-macOS-Trash flow for selected caches. Restart relaunches Hello Mini with saved state; Shut Down quits Hello Mini.
- **Menu item blink:** Flash the chosen System 7 menu command three times before closing the menu, executing its action once. Skip the effect with Reduce Motion or Playfulness disabled, and preserve keyboard interaction.

## Small new desk accessories

- **Key Caps:** A period keyboard viewer that doubles as a Unicode and emoji picker, with click-to-copy. A useful character palette in a vintage keyboard costume.
- **Alarm Clock:** Add timers and a pomodoro to the existing Clock module. When an alarm fires, flash an alarm icon in the menu bar and use the shared system sounds. Preserve a visible alarm when sound is muted, and use a steady indicator with Reduce Motion or Playfulness disabled. Define sleep/wake and relaunch behaviour as part of the timer design.
- **Find File:** A Sherlock-style search window backed by Spotlight metadata queries, with the little dog. Give Finder a search entry point and let results open or reveal real files; communicate indexing or access limitations in the window.
- **Desktop pattern editor:** Recreate the classic 8 × 8 pixel editor from the General control panel, feeding the theme's dotted desktop surface. Save the pattern, preview changes, and offer a reset to the theme default.
- **Finder labels:** Offer System 7's seven colour labels backed by real macOS Finder tags. Read existing labels and change the chosen colour without discarding unrelated tags.

## Theme fidelity and discoverability

- **Aqua dock and windows:** Add dock magnification on hover and a genie-style minimise animation to the existing dock and window restoration behaviour. Gate both through Playfulness and Reduce Motion, preserving reliable focus, window interaction, and restoration when effects are skipped.
- **System 7 Balloon Help:** Add hover explanations in period speech balloons as a shared discoverability layer for desktop controls and applications. Provide an explicit help toggle and equivalent explanations for keyboard and accessibility users.

## Other continuing directions

- **Themes:** System 7 and Mac OS X 10.0–inspired Aqua are available, including pinstripes, gel controls, original smooth icons, working Aqua traffic lights for close, minimise, and zoom, and a dock with running indicators and minimised-window restoration. More era-specific controls can follow without duplicating application behavior.
- **More spectacle:** Flying Toasters is implemented. Living dither, Impossible instruments, Physical windows, and Depth behind glass remain future effects, all optional through Playfulness.
- **Distribution:** The MIT-licensed 0.1.0 release is available as a signed, notarized GitHub download, linked from hellomini.app. Evaluate a Homebrew cask next; App Store distribution remains undecided. CI continues to produce development artifacts separately from public releases.
- **Compatibility:** macOS 26 remains the baseline; consider macOS 15 only if it does not hinder selective adoption of newer features.

See the [user guide](docs/USER_GUIDE.md) for what works today and [CI documentation](docs/CI.md) for the existing build pipelines.
