# Roadmap

Hello Mini's guiding principle is **quintessential idiocy**: useful little applications, period-looking interfaces, and modern capabilities that would have been utterly impossible on the original hardware. Silliness is part of the product. Each accessory should be a coherent little application, whether practical or gloriously unnecessary.

The [user guide](docs/USER_GUIDE.md) describes shipped behaviour; the [changelog](CHANGELOG.md) records release history. Downloads and the Homebrew cask are available through the [installation guide](docs/INSTALL.md).

## What is implemented

- A persistent desktop with six themes, window controls, menus, keyboard launching, portable desktop presets, enlarged interface scales and fixed-resolution Purist mode.
- Finder and Find File; Activity Monitor, Disk First Aid and reviewed cache cleanup; Chooser and Network; clocks, alarms, Calculator, Key Caps and Clipboard.
- Scrapbook with search, on-device picture text recognition, collections, favourites, batch filing, recovery and portable backups; MiniPaint with drawing, Undo/Redo and explicit Scrapbook/pattern connections.
- Print Monitor with GitHub/GitLab queues, history, jobs, artifact downloads and reviewed retries; Communications for configured telemetry backends.
- Aquarium, Teapot, live Puzzle, Talking Moose and screensavers, plus optional themed effects including Living dither, Impossible instruments, Physical windows, Depth behind glass and Paper shuffle.

## Next directions

- **Finder:** multi-step Undo/Redo, cross-volume Move, conflict replacement and transfers beyond the current 512 MB/10,000-entry limits. Each needs explicit review, cancellation and recovery behaviour; existing single-operation Undo/Redo must stay conservative.
- **Accessibility:** complete the accessory keyboard matrix and spoken end-to-end VoiceOver audit. Continue checking small-window layouts and theme-specific controls as workflows grow.
- **Hardware reliability:** complete actual full-system sleep/wake during an idle Mini window, attended cable hot-plug and a multi-hour Wokyis soak. The physical reading comparison supports 2× over 1.5× for the tested setup; remote screenshots do not establish legibility.
- **CI providers:** expand live history/artifact/retry coverage on configured Enterprise and self-hosted installations. GitLab has fixture coverage but no live test instance is currently available. Additional providers should use the existing provider contract.
- **Packaging:** decide external compiled-plugin distribution when contributor needs justify it. Standalone macOS screensaver packaging, App Store distribution, cloud sync and broader platform compatibility remain future decisions.
- **Accessory depth:** more keyboard layouts/live highlighting in Key Caps, richer painting tools and further era-specific theme controls can follow concrete user needs.

## Design and maintenance commitments

Keep applications in separate SwiftPM modules with host-injected connections. Share themed controls and presentation policy rather than duplicating application behaviour per theme. Keep optional spectacle in Playfulness, preserve useful information when it is disabled, and respect Reduce Motion, visibility and lifecycle gates.

Preserve unreadable/newer saved data, keep migrations recoverable and make filesystem mutations explicit. Validate the affected workflows at minimum size, 2× and Purist dimensions. Keep release history in the changelog and test evidence in dated validation records, so current guides describe the current product.

## Validation evidence

The [validation index](docs/VALIDATION.md) links dated release and hardware records and tracks open coverage. These are dated observations, not claims that every later binary repeated the hardware checks.
