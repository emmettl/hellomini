# Tiny-screen mode

Tiny-screen mode enlarges Hello Mini's text, controls, icons, menus and window chrome together. It is intended for physically small displays, including the 1280 × 720 Wokyis. A screenshot that fits the panel does not establish comfortable reading at desk distance.

[User controls](USER_GUIDE.md#tiny-screen-mode) · [Architecture](ARCHITECTURE.md#display-presentation) · [Validation](VALIDATION.md)

## Presentation policy

Standard mode uses 1× presentation. Tiny-screen mode is an opt-in saved setting with a default 2× scale and an optional 1.5× comparison preset. Purist mode is mutually exclusive and retains its fixed 512 × 384 logical canvas. Existing saved 2× choices remain unchanged when upgrading.

The host divides the available desktop dimensions by the selected scale and lays out windows in those logical coordinates, then scales the result for presentation. A 1280 × 720 desktop becomes 640 × 360 logical points at 2×. The shared `miniDisplay` environment conveys scale and logical size; themes and accessories do not multiply their own font or control sizes.

Desktop, startup, screensavers and custom sheets share this policy. Sheets live in separate native windows, so `miniSheet(width:)` applies the scale once and bounds a scrolling viewport to the logical desktop. Native macOS menus, alerts and file panels retain system sizing. An inset bevel and rounded screen corners remain visible in full screen.

## Layout and interaction

Finder uses a separate path line and Places toggle in narrow windows; Print Monitor stacks filters/build rows and scrolls compact content. Control Panel prioritises appearance controls. Accessories reflow for small dimensions, with minimum-content scrolling as a fallback. The Aqua dock reserves a smaller area on short desktops. The theme strip is pure SwiftUI so enlarged drawing and pointer hit areas use the same coordinates.

Changes must keep window chrome, menus, essential actions, keyboard navigation and overflow reachable without shrinking essential text back down. Keep saved geometry in logical coordinates and preserve open documents when switching display modes. Test native sheets, help placement, captures, graphics and full-screen transitions as well as the main desktop.

## Evidence and remaining checks

The [physical reading comparison](0.10_VALIDATION.md) found 2× readable and 1.5× too small for the user at their normal viewing distance. That supports 2× for the tested setup, rather than a universal legibility claim. The [Wokyis record](WOKYIS_VALIDATION.md) distinguishes physical resolution/display-sleep checks from virtual-display observations.

Automated coverage checks display preferences, presentation geometry, window chrome and compact controls across all six themes. Dated release records document the workflows actually checked. Spoken VoiceOver, the complete accessory keyboard/graphics matrix, full system sleep/wake, cable hot-plug and a multi-hour soak remain open; see [validation status](VALIDATION.md).

For affected changes, check Standard, 1.5×, 2× and Purist modes; minimum window sizes; windowed/full-screen transitions; relaunch persistence; and Reduce Motion. Physical tests should record display identity, resolution, scale and viewing conditions. Remote screenshots cannot replace a reading-distance check.
