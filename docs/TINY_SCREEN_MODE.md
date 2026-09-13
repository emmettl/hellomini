# Tiny-screen mode — 0.3.0 scope and design

Status: first implementation in source, unreleased. This document defines the focus of 0.3.0. The 2× prototype requires physical-display validation before choosing the release default.

[Roadmap](../ROADMAP.md) · [Current architecture](ARCHITECTURE.md) · [Current user guide](USER_GUIDE.md)

## Implementation progress

The first implementation includes a saved 2× setting in Control Panel, the desktop View menu, and the native View menu; mutually exclusive Purist mode; a shared `miniDisplay` environment; and logical layout plus presentation scaling at the host boundary. Desktop, startup, screensavers, and custom sheets use that policy. An inset bevel and rounded screen corners are drawn inside the app, including in full screen.

Finder now moves its path onto a separate line in narrow windows and provides a Places toggle. Compact list rows prioritise filenames. Print Monitor collapses filters and stacks build rows in compact windows, with the whole queue scrollable; roomy windows retain their fixed toolbar. Control Panel brings the display toggles to the top in tiny-screen mode. Other oversized app content retains the shell's minimum-content scrolling fallback. This is an initial implementation, not completion of the full app/workflow audit below.

Validation completed on the development Mac: `make check` (105 debug tests, 13 release tests, lint, build/release tooling checks, and build); a local app build; visual checks of all five themes at 2×; native-sheet text entry and overflow; full-screen transitions; relaunch persistence; and a 512 × 384 Purist-mode transition. Automated checks cover conflicting/legacy preferences, logical display sizing, actual rendered enlargement/corners, and reachable window chrome with both launcher styles at 1280 × 720 and 960 × 600 host sizes.

Still required before 0.3.0: physical Wokyis reading tests and the 1.5× comparison, the full bundled-app and keyboard/graphics workflow matrix, minimum-size visual checks, and longer display-change/sleep/wake testing. The native View-menu items were inspected, but their activation could not be verified through the UI automation tool, which returned stale element IDs; Control Panel and desktop-menu activation were verified. Native OS menus, alerts, and file panels remain OS-sized. Screenshots from a development monitor do not establish physical legibility on the Wokyis.

## Goal

Make Hello Mini readable and comfortable to operate on the physically small Wokyis display at normal desk distance. Fitting the existing interface into 1280 × 720 does not establish legibility: the theme framework currently uses body text around 13 points and secondary text around 11 points, alongside small controls and detailed application views.

Enlarge all Hello Mini UI together: text, icons, controls and their hit areas, rows, window chrome, menus, status indicators, scroll controls, and help. Show less information at once when necessary. Keep essential labels and actions readable, including errors, empty states, and disabled states.

## User experience

- Add **Tiny-screen mode** to **Control Panel → Appearance** and the native **View** menu. Changes apply immediately and persist across relaunches. Keep the View-menu escape route accessible even when the desktop is crowded.
- Keep the setting independent of theme selection and available with Classic, Paper, Midnight, System 7, and Aqua. Theme changes retain the selected mode and running application state.
- Begin evaluation at **2×**. Compare **1.5×** on hardware before choosing the shipping default. Avoid a continuous slider in the initial scope; expose a second preset only if testing demonstrates a useful tradeoff.
- Keep standard mode as the initial default for new and existing installations. Offer tiny-screen mode explicitly; resolution alone cannot identify a physically tiny monitor or viewing distance. Automatic detection and per-display profiles can follow later.
- Keep the current window/full-screen behaviour when enabling tiny-screen mode: it uses the available content area. Unlike Purist mode, it does not shrink the native window to a small fixed canvas.
- Preserve the desktop's bevelled edges when entering full screen, including in tiny-screen mode. Keep this edge treatment visible within the available display bounds so it is not lost or clipped at the screen boundary.
- Make Standard, Tiny-screen, and Purist mutually exclusive effective modes. Enabling either special mode disables the other; disabling the active special mode returns to Standard. Preserve existing Purist preferences during migration.

The main tradeoff is workspace size. Assuming an available content area of 1280 × 720 macOS points, the candidates are:

| Presentation scale | Logical workspace before shell chrome | Existing 13-point body text appears at |
| --- | --- | --- |
| 1×, Standard | 1280 × 720 | 13 points |
| 1.5×, candidate | approximately 853 × 480 | 19.5 points |
| 2×, starting candidate | 640 × 360 | 26 points |

These are presentation sizes, not a change to the panel resolution. Actual logical space depends on macOS display scaling and the native window's available area. The menu bar and Aqua dock further reduce application space. Hardware testing must establish whether 2× is sufficient and comfortable at the user's actual desk distance.

## Architecture and the theme API

Use a shared display policy, integrated with the theme framework. The selected era should determine visual styling; the display policy should determine how large that interface appears.

The preferred first implementation is to lay out the desktop in a smaller logical coordinate space and apply one presentation scale at the host boundary. Derive logical size from available content size divided by that scale. This covers existing fixed-size application controls and custom theme renderers consistently. A visual transform on the current full-size layout alone would crop the desktop, so the layout proposal and presentation must change together.

Keep SwiftUI text and vector content live through the transform. Do not implement the desktop as an enlarged screenshot. Prototype native view embedding, text input, scrolling, and Metal rendering early: these are implementation risks, not capabilities established by this design.

| Owner | Proposed responsibility |
| --- | --- |
| `MiniCore` / `AppearanceSettings` | Persist the effective display mode independently of the theme ID; define migration and mutual exclusion. |
| `MiniDesktop` / `MiniDisplayViewport` | Resolve logical size and presentation scale, map coordinates, constrain windows, and present desktop/startup/screensavers consistently. |
| `MiniUI` | Expose a read-only display/layout context for responsive views and custom renderers. Add shared semantic metrics for recurring control sizes as the layout audit identifies them. |
| `MiniThemeDefinition` and theme modules | Supply typography, artwork, and base dimensions in logical units. Consume shared metrics where needed; avoid applying presentation scale again. |
| Application modules | Reflow content for available logical width and height, retain essential actions, and provide deliberate overflow for content that cannot fit. |

The proposed context should communicate effective mode, presentation scale, and available logical size; exact API names remain an implementation decision. Prefer available-size decisions for reflow so improvements also help ordinary small windows and Purist mode. Custom theme renderers must preserve enlarged hit areas, focus/accessibility semantics, and action callbacks.

Fonts in `ThemeTypography` are already constructed `Font` values, and theme dimensions only cover part of the UI. Changing those fonts alone would miss many fixed frames, icons, controls, and application layouts. Broadly replacing the theme API is unnecessary for the first release; extend it where a concrete shared sizing need appears, keeping existing theme registrations working.

## Layout and interaction requirements

At 2×, even the full logical desktop is only 640 × 360. Finder and Print Monitor currently declare minimum window widths of 640, before allowing for desktop margins, and minimum heights of 400 and 420. Existing minimum-content scrolling is a useful fallback, but it is not sufficient for the main workflows.

- **Shell:** Keep title bars, close/minimise/zoom controls, resize grips, menus, and status reachable. Revisit the existing compact menu behaviour, which switches to smaller typography below 800 logical points. Recover space by reducing secondary content and providing overflow instead of reducing essential type sizes. Keep keyboard menu selection visible.
- **Launchers:** Audit both the desktop rail and Aqua dock. Every app and minimised window must remain reachable by pointer and keyboard, with clear overflow controls. Evaluate the dock's vertical cost before settling the 2× layout.
- **Control Panel:** Keep the mode toggle and pane navigation visible or immediately reachable; stack settings and constrain previews. The user must be able to reverse the mode without navigating a wide, clipped form.
- **Print Monitor and Finder:** Prioritise primary rows and actions, wrap or stack toolbars, and move secondary columns/details into reachable detail views. Keep CI failures, filenames, and action labels legible. Avoid requiring horizontal scrolling for their primary tasks.
- **All other apps:** Audit content, dialogs, editors, tab strips, numerical displays, error messages, and empty states. Allow vertical scrolling for long content and horizontal scrolling where the content intrinsically requires it, such as images or wide data. Do not silently shrink UI to satisfy existing minimum sizes.
- **Coordinates and state:** Use one logical desktop space for drag/resize, zoom, hit testing, anchors, help placement, and visibility calculations. Verify native view/event conversions separately. Mode changes temporarily constrain displayed geometry without overwriting saved placements; deliberate drag/resize continues to save normally. Preserve app instances, drafts, selection, and focus where the focused control remains available.
- **Graphics and capture:** Keep startup and screensavers inside the same presentation policy. Check Metal drawable sizing and pointer interaction, and define the output size for desktop captures explicitly. Preserve graphics pause/visibility and Reduce Motion behaviour.

Native macOS file dialogs, context menus, system tooltips, the system pointer, and the system menu bar remain OS-managed. In-app presentation scaling cannot guarantee their enlargement. Inspect these flows on the device and record any remaining limitation; if an essential workflow is unusable, resolve it before claiming that workflow is supported in tiny-screen mode.

## Delivery and acceptance

1. **Prototype the presentation boundary.** Verify 1.5× and 2× geometry, input, native controls, Metal, and mode transitions. Use Control Panel, Print Monitor, Finder, and Aqua chrome to expose problems early. Reassess the host-scale approach if native integration fails.
2. **Implement the shared setting and responsive layouts.** Wire persistence, recovery, shell overflow, and theme/layout context; complete the primary workflows and then the full app audit.
3. **Validate and document the release.** Add meaningful geometry, persistence/migration, and interaction regression checks. Visually inspect all five themes at standard and candidate tiny sizes, windowed and full screen. Check Purist behaviour remains intact.

Release requires the following evidence:

- On the physical Wokyis, record the panel/macOS display setting, chosen scale, ambient conditions, and measured normal viewing distance. Read menus, CI status/failure details, filenames, clocks, and settings comfortably without leaning in. Choose the default from this evaluation, not from screenshots alone.
- Complete launching/restoring apps, dragging/resizing windows, keyboard menu navigation, scrolling, editing text, changing themes, and turning the mode off. No essential action may be trapped outside the visible area.
- Across all themes and bundled apps, essential text and controls remain legible, overflow is usable, and custom icons/chrome stay crisp enough at the chosen scale.
- Compare windowed and full-screen presentation to verify that the desktop's bevelled edges remain visible and intact, including after toggling tiny-screen mode and exiting/re-entering full screen.
- Test relaunch, mode switches, display changes, full-screen entry/exit, and sleep/wake. Preserve app data and saved geometry, and check focus, help anchoring, capture output, and graphics lifecycle.
- Retain the standard 1280 × 720 experience and the existing fixed 512 × 384 Purist mode. Update the user guide and changelog only when behaviour is implemented and verified.

External theme/plugin distribution, new themes, OS-wide scaling, automatic physical-display detection, and unrelated accessories are outside this feature's 0.3.0 scope.
