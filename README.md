# Hello Mini

<img src="Support/AppIcon.png" width="96" alt="Hello Mini pixel Macintosh icon">

A tiny Macintosh desktop with a deeply unreasonable amount of modern capability. Real utilities, monochrome Metal spectacles, and fish that get lunch when your builds pass.

**Apple silicon · macOS 26 · designed for 1280 × 720 · MIT licensed**

[Build and install](docs/INSTALL.md) · [Changelog](CHANGELOG.md) · [Roadmap](ROADMAP.md) · [Contributing](CONTRIBUTING.md)

The first public binary release is in preparation. You can build from source today; a notarized download and Homebrew cask are not available yet.

## Introduction

This project is to build a homage to early macOS, intended to run on the Wokyis M5 retro docking station, but usable on other systems.

It should
 - be a visually-faithful, playful homage
 - be extensible (shippable binaries that can be developed by third-parties; plugins containing compiled code and assets are one option, with the exact extension model to be decided later)
 - be able to display useful information
 - actually function as a finder
 - work well on a full screen, 720p display

The default look targets the early black-and-white Mac OS era. System 7-inspired colour and early Aqua themes are also available, including Mac OS X 10.0-era pinstripes and glossy traffic lights.


## Technology
- macOS 26 baseline. A macOS 15 fallback may be considered later, provided it does not hinder selective adoption of newer features.
- Swift 6.3+
- SwiftUI
- Swift Testing
- `swift-format` for source formatting and style linting
- AppKit (if needed to create the kinds of effects necessary due to gaps in SwiftUI)

## Deployment

The first distribution channel will be a Developer ID-signed, notarized ZIP on GitHub Releases. Homebrew can follow once a stable download exists. App Store distribution remains undecided. See the [release preparation guide](docs/RELEASING.md).

## But Why, Though?

Because charm is sometimes more important than practicality.  And because it is a challenge to see what can be done.

The [roadmap](ROADMAP.md) collects the planned applications and their contributions to the project's quintessential idiocy, from a genuinely useful Chooser to a sliding puzzle made from the live desktop.

## Running the first desktop

Requires macOS 26 and Xcode 26.6 or another toolchain with Swift 6.3+.

```sh
make run     # Build a local app bundle and launch it
make check   # Check formatting, run Swift Testing, and build
make format  # Apply swift-format
```

Open `Package.swift` in Xcode to work on the package. `make app` produces `dist/Hello Mini.app` with a local ad-hoc signature; public distribution requires the separate Developer ID and notarization steps in the release guide.

GitHub Actions runs public checks on hosted macOS 26 runners. Trusted builds on the Mac Mini use a separate private repository, with a mandatory Metal test and downloadable release-build artifacts. See [the CI setup](docs/CI.md) for the repository separation, manual build controls, and runner maintenance. `make app CONFIGURATION=release` builds the same release configuration locally.

The desktop opens at 1280 × 720. Use View → Enter / Exit Full Screen (or Control-Command-F) for a dedicated display. Drag the striped title bars to move windows, or the bottom-right corner grips to resize them. Grips also expose accessibility increment/decrement actions. Each app supplies a minimum size; windows stay inside the available desktop. The Window menu reopens closed windows and **Reset Window Layout** restores their default positions and sizes. Aqua adds working red **Close**, yellow **Minimise**, and green **Zoom** controls, with hover symbols and inactive grey states. Zoom fills the available desktop and toggles back to the previous geometry; dragging or resizing a zoomed window establishes a new normal size. Minimise keeps the application and its view state alive, hides the window, and gives focus to the next visible window. Restore it from the Aqua dock, its desktop icon in other themes, or its labelled entry in Window. **Window → Minimise** (Command-M) and **Zoom / Restore Size** are available in every theme.

**Control Panel → Appearance → Purist mode — 512 × 384** runs the desktop at a fixed 512 × 384 logical resolution. It works with every theme and is also available in **View → Purist Mode**. The native app window shrinks to fit; turning the mode off restores its previous larger frame, including after relaunch. Full screen centres the same small desktop against black. Startup uses a compact layout, and screensavers use the same fixed canvas. Menus use compact headings and scroll when long; keyboard selection keeps the selected row visible. App windows retain their saved geometry and expose scrolling when their minimum content is larger than the available window. The Aqua dock still reserves its space and offers overflow navigation. Theme changes and display-mode changes keep application state; deliberate dragging/resizing still saves new geometry. The setting is off by default and survives relaunch.

Open applications, stacking order, positions, sizes, and minimised/zoomed states are saved automatically and restored after the startup sequence. A deliberately empty desktop stays empty. On a first launch, Activity Monitor opens by default. Layouts adapt to the current display without overwriting the saved geometry until you move or resize a window. Unknown application IDs are ignored, and unreadable or unsupported session data falls back to the initial layout.

At launch, a brief Macintosh boot homage shows a happy Mac, then “Welcome to Macintosh.” with a stepped progress bar and a row of startup icons. It uses the selected theme and lasts about four seconds before opening the desktop. Click **Skip startup** or press Escape to enter immediately. **Control Panel → Playfulness → Macintosh startup** disables it for subsequent launches; the Extra silliness master switch and macOS Reduce Motion also bypass it. An original chime accompanies startup when System sounds is enabled. The presentation does not measure system boot or application loading. Desktop windows and their input handlers are created afterward. The sequence runs once per launch and does not replay when changing themes, focusing the app, or reopening an application window.

The desktop menu bar uses custom monochrome dropdowns with checkmarks, disabled commands, and shortcut labels. Click a heading to open it, then move across headings to switch menus. Arrow keys navigate, Return activates the selected command, and Escape or a click outside dismisses the menu. Command shortcuts also work while menus are closed; native folder dialogs retain their normal keyboard behavior.

The Finder browses real folders, with icon and list views, back/up navigation, hidden-file visibility, and a folder chooser. Its last folder, icon/list mode, and hidden-file preference survive relaunches; navigation history starts fresh. Missing or inaccessible restored folders use the normal error view and folder chooser. Double-click a folder to browse it or a file to open it with its default macOS application. Right-click an item to reveal it in macOS Finder. Folder access follows normal macOS permissions; errors appear in the window. The context menu also offers seven colour labels, updating the matching named macOS tag and legacy colour while preserving unrelated tags. File contents are unchanged; move and delete operations remain future work.

## Applications and architecture

Each application is its own SwiftPM target, depending on `MiniCore` and the shared `MiniUI` controls. `MiniCore` defines the `MiniApplication` contract and command descriptions. `MiniDesktop` owns application launching, window positions, focus, stacking, and menu rendering; it does not import any application target. `HelloMini` registers the application instances and chooses which open at startup.

`MiniDesktop` saves a versioned session in local app preferences, keyed by stable application IDs. Geometry is committed when a drag or resize ends; tracking uses a fixed desktop coordinate space and does not write preferences on every pointer update. Application-specific preferences remain inside their own modules. `MiniApplication.minimumSize` defaults to the app's default size, and apps with flexible content can provide smaller limits. Finder currently stores its last folder as a local path; an eventual App Sandbox distribution will need scoped-bookmark access restoration as part of that packaging work.

- `MiniFinder` owns directory reading, navigation history, labels, Finder, and Spotlight-backed Find File.
- `MiniAccessories` supplies Clipboard and Key Caps.
- `MiniActivityMonitor` shows local CPU usage and a two-minute graph, memory statistics, load averages, uptime, disk free space on the home volume, and processes. It opens at startup for the CI display. Updates run off the UI actor every two seconds while the window is open, with pause/resume, name/PID filtering, and CPU or memory sorting.
- `MiniClock` supplies Alarm Clock (saved timers and focus/break sessions), Clock (local/UTC time and a monotonic stopwatch) and World Clock (saved time zones, working hours, and a decorative globe). A running stopwatch continues counting while its window is closed.
- `MiniControlPanel` provides Appearance and Playfulness panes, with live theme previews and saved effect switches. Classic uses the original dotted desktop, Paper uses a plain white desktop, and Midnight uses white ink on black. System 7 adds a lavender desktop, coloured icons, striped grey title bars, rounded outlined buttons, and proportional type. Select a preview or use the app's Appearance menu; the choice applies immediately and persists across launches.
- `MiniAbout` shows application and system information.
- `MiniAquarium` owns a Metal fish tank, lightweight CPU/network sampling, and shared content for the screensaver host. It depends only on the core and shared UI modules.
- `MiniScrapbook` keeps searchable notes, commands, links, and image snapshots in local storage, with recoverable archiving. It depends only on the core and shared UI modules.

`AppearanceSettings` in `MiniCore` stores the selected theme in the app's preferences and falls back to Classic if a saved theme is unavailable. The executable shares one settings instance with the desktop and Control Panel. `MiniUI` supplies `MiniThemeDefinition`, the theme registry, and the `miniTheme` environment value used by windows, menus, icons, and app content. Themes affect Hello Mini's appearance, not the Mac's system-wide appearance. Theme changes keep open applications and their state intact.

Launch apps from their desktop icons, the Macintosh menu, or Window. The active application supplies its own menus. Closing Activity Monitor stops its sampling task; reopening resumes unless it was paused. Resuming begins a fresh CPU history rather than presenting old readings as recent. All applications are currently compiled into the executable; external plugin loading remains undecided.

Activity Monitor's system CPU percentage is the difference between kernel CPU tick counters, normalized across all cores. Its first reading needs two samples. Process CPU comes from `ps` and can exceed 100% for multithreaded processes; process memory is RSS, which can include shared pages. These values do not sum to the system totals. Memory shows wired, compressed, and free physical pages separately, not a memory-pressure estimate. No process termination controls are included. Only executable names are read, never command arguments. This monitors the local Mac, not CI workflow or job status.

The current build requires macOS 26; macOS 15 compatibility has not been validated.

## Public release direction

The aim is a public GitHub project that other people can install and enjoy, with distribution channels such as Homebrew to be evaluated later. Build CI and local release-preparation tooling are configured. Public signing still needs a Developer ID Application identity and notarization credentials; no binary release has been published yet. Print Monitor now supports GitHub Actions and GitLab.com pipelines through provider modules and per-user configuration. Aquarium and Flying Toasters now share an app screensaver host with optional idle activation. Standalone macOS screensaver packaging remains future work. See the [roadmap](ROADMAP.md) for the full application lineup.

## App icon

The Dock and Finder icon uses the same pixel Macintosh artwork as the desktop. `make icons` generates all ten standard/Retina icon representations (16 through 1024 pixels), `Support/AppIcon.icns`, and a 1024-pixel preview at `Support/AppIcon.png`. Small icons use the pixel silhouette directly; larger icons sit on a white tile. Edit the computer artwork in `Sources/MiniUI/PixelSymbol.swift` or the rendering in `scripts/GenerateIcons.swift` to update it. App builds regenerate changed artwork and copy the icon into the bundle before signing.

## Theme framework

Themes are registered values with stable string IDs, rather than a closed enum. `HelloMiniApp` owns the `MiniThemeRegistry` and gives its metadata to `AppearanceSettings`, and the same registry to the desktop and Control Panel. Control Panel discovers every registered theme automatically and its scrollable previews use the real shared renderers. The appearance strip has a persistent horizontal scrollbar, independent of macOS overlay-scrollbar preferences. The existing `classic`, `paper`, and `midnight` preference IDs are preserved; unavailable themes fall back to Classic (or the first registered theme) without erasing the saved preference.

`MiniSystem7Theme` and `MiniAquaTheme` each depend on `MiniCore` and `MiniUI`, export a `MiniThemeDefinition`, and are added by the executable to the shared registry. No application or desktop behavior needs an era-specific switch. Definitions provide:

- Semantic foreground, background, accent, and selection colors; body, small, title, and display fonts. Optional desktop text colors, label surfaces, and text shadows allow readable labels over a coloured wallpaper without changing window content.
- Solid, gradient, dotted, pinstriped, bundled-image, and custom SwiftUI surfaces.
- Active/inactive window frames, corner radii, borders, shadows, title-bar height, and menu dimensions and surfaces. An optional dock frame enables the shared dock and reserves its desktop area; themes supply styling while the shell owns launching and restoring.
- Optional title-bar, button, and semantic-icon renderers for artwork and controls that cannot be expressed by tokens alone. Title bars receive the window title, active and zoomed states, the close action, and optional minimise/zoom actions; buttons receive pressed/enabled state and their original label. Custom renderers must retain those actions and accessibility labels.

App views read `@Environment(\.miniTheme)` for styling and use `RetroButtonStyle` and `PixelIcon` for shared controls and semantic artwork. The desktop retains dragging, focus, window ordering, keyboard navigation, and command dispatch. Theme replacement does not key or recreate application state. Native macOS dialogs and context menus remain native, with the theme's light/dark color scheme where applicable.

For example, a theme module can start with:

```swift
var theme = MiniThemeDefinition(
  metadata: MiniTheme(id: "org.example.pinstripes", name: "Pinstripes", description: "A custom theme"))
theme.window.surface = .pinstripes(
  background: .white, foreground: .gray.opacity(0.15), spacing: 4, lineWidth: 1)
theme.window.cornerRadius = 10
theme.inactiveWindow = theme.window
theme.selection = .gradient([.cyan, .blue])
theme.typography.body = .system(size: 13)
// Register alongside MiniThemeRegistry.builtIns.themes in HelloMiniApp.
```

Declare module assets with SwiftPM `resources: [.process("Resources")]` and reference them inside that module with `.image(name: "Texture.png", bundle: .module, tiled: true)` or a custom renderer. The app bundler copies resource bundles of local targets belonging to the executable, excluding test targets, into `Contents/Resources` before signing. Use `MiniResourceBundle.resolve(named: "HelloMini_YourTarget", developmentBundle: .module)` inside the module to resolve the bundle in both signed app builds and SwiftPM runs; pass that resolved bundle to image and file loaders. SwiftPM's generated accessor alone expects bundles at the app root, which macOS code signing rejects. Bundled fonts can be registered by their owning module and supplied as `Font.custom` values. External package/plugin loading and distribution remain future work.

`MiniUITests` exercises an unshipped color theme with pinstripes, gradients, rounded frames, custom renderers, and a bundled image; it also checks actual rendered pixels for each surface type. The shipped System 7 and Aqua modules test selection persistence, rendered active/inactive chrome, and coloured/selected icons. Aqua additionally checks traffic-light colour ordering, disabled controls, gel-button states, periodic pinstripes, and distinct artwork for all 15 semantic icons. Desktop tests cover minimise/focus restoration, zoom geometry across display sizes, and compatibility with existing saved sessions. Both use original artwork and system fonts rather than bundling Apple artwork or fonts.

**Control Panel → Appearance → Aqua** selects the early OS X homage: blue wave wallpaper, fine horizontal pinstripes, rounded shadowed windows, glossy red/yellow/green window buttons, blue gel controls, and smooth colourful icons. A translucent dock replaces the desktop app column in Aqua, with all applications, running triangles, hover labels, and separate minimised-window tiles after a divider. Click an app to launch, focus, or restore it; click a minimised tile to restore its window. Icons shrink to fit, and crowded docks offer horizontal scrolling and arrows to reach either end. **View → Focus Dock** enables left/right keyboard navigation; Space or Return activates the selected item and Escape leaves the dock. Window zoom, drag, and resize bounds reserve space above the shelf without rewriting saved positions on a theme change. Minimise state survives relaunch, so its tiles return too. Other themes retain the desktop application column. The wallpaper is static and adds no animation loop; existing graphics and playfulness controls continue to work. The app's Dock icon stays the shared Hello Mini identity.

Known visual limitation: a theme thumbnail can partially repaint after a live appearance change. Reopening Control Panel refreshes the previews; desktop styling and application state are unaffected.


## Teapot

`MiniTeapot` is the first deliberately anachronistic graphics app: the Utah teapot rotating inside a monochrome Macintosh window. Launch **Teapot** from its desktop icon or the application menus. Choose Dither, Smooth, or Wireframe, pause/resume rotation, use the arrow buttons to orbit, or reset the view. Dither uses a fixed ordered pattern in the current theme's ink and paper colors.

Metal renders the geometry, lighting, specular highlights, depth testing, and dithering. The Bézier control net is tessellated once when the view is created and uploaded to GPU buffers; per-frame updates send only camera and palette uniforms. The view targets 60 fps while active, skips GPU work when occluded, pauses when the app is inactive, and releases its draw delegate when closed. Reduce Motion disables automatic rotation while retaining manual orbit controls. No GPU is required for the rest of the desktop; this app shows an explanation if Metal initialization fails.

The control points come from [freeglut's Utah teapot data](https://github.com/freeglut/freeglut/blob/master/src/fg_teapot_data.h); the permission notice ships alongside the model. `MiniTeapotTests` validates the mesh and renders actual Metal frames to verify palette inversion, dithering, shading modes, and changing viewpoints.


## Playfulness

Creeping anachronism is part of the design: modern GPU effects should borrow the selected theme's visual language. **Control Panel → Playfulness** has an **Extra silliness** master switch and individual effect switches, independent of the theme. Choices apply immediately and persist across launches. Disabling the master switch preserves each effect's preference.

**Teapot animation** is one of the working switches. It stops automatic rotation in an already-open Teapot window, retaining manual orbit, shading modes, and the app's own pause/resume choice. Re-enabling it does not open Teapot or undo a manual pause. Reduce Motion still prevents automatic rotation.

`PlayfulnessSettings` and `MiniPlayfulEffect` live in `MiniCore`. Effect modules export metadata with stable IDs; `HelloMiniApp` registers implemented effects and injects one shared settings instance into Control Panel and the modules that use it. Control Panel discovers these switches automatically. Renderers check `allows(id)` before scheduling their effects and also honor Reduce Motion and their own visibility/lifecycle rules. Removed modules cannot run through the settings catalog, but their saved choices survive reinstallation. Theme modules supply appearance, not effect preferences.

The Playfulness pane also lists the future ideas explicitly as planned: fluid **Living dither**, particle-based **Impossible instruments**, folding **Physical windows**, and stippled 3D **Depth behind glass**. These renderers are not implemented yet; each will receive its own working switch when registered.

## Screensavers

**Control Panel → Screensavers** selects Aquarium or Flying Toasters, previews the selected saver, and sets an idle delay of 1, 2, 5, 10, 15, or 30 minutes. The default is **Never**. Selection and delay survive relaunches. Aquarium's own **Screensaver preview** button previews its fish without changing the saved selection.

**Flying Toasters** supplies original procedural pixel artwork: winged appliances and slices of toast travelling diagonally across a field of theme ink. Metal renders the parade at up to 30 fps with a bounded drawable. **Control Panel → Playfulness → Flying toaster animation** freezes the flight; Aquarium retains its own animation and activity switches. Turning off **Extra silliness** disables both previews and idle activation while preserving preferences. Reduce Motion disables automatic activation and keeps manual previews still.

Automatic activation requires Hello Mini to be active, with its desktop window visible and focused, no native sheet or modal dialog, and no held mouse button or live window resize. Input resets the timer. Time spent inactive, asleep, or across a delayed timer callback does not count toward activation. The saver covers the desktop window's current display; it dismisses on mouse movement, clicking, scrolling, or a key press, and when focus leaves it. The waking event is consumed so it does not also invoke a desktop command. macOS sleep and lock behaviour are unchanged; this is an app presentation, not an installed `.saver` or lock screen.

`MiniCore` owns saver metadata and preferences. `MiniScreensaver` owns presentation, idle timing, and input handling; registered definitions supply content and optional start/stop hooks. `MiniToasters` registers the toaster effect and renderer. The executable wires Aquarium into the same registry without an Aquarium dependency on the screensaver host. Covered desktop graphics pause through the desktop visibility environment, while window positions, editors, and application models stay intact.

## Aquarium

Open **Aquarium** from the desktop or application menus for nine fish, bubbles, plants, gravel, and stippled underwater light. **Feed fish** drops food and draws the fish toward it; **Pause** freezes the tank without accumulating motion to catch up on later. The Aquarium menu provides the same feeding and pause controls. Desktop icons scroll when the display cannot fit the full application list.

**Control Panel → Playfulness → Aquarium animation** and the Extra silliness master switch control automatic motion. Reduce Motion also keeps the tank still. **Reflect system activity** is off by default and persists independently: enable it in Control Panel or the Aquarium menu for CPU-driven plant and bubble currents and extra bubbles from network traffic. The tank displays numerical readings alongside the animation. Sampling runs in an actor every two seconds while the tank is open and Hello Mini is active. It reads CPU tick deltas and combined inbound/outbound byte counters for active Ethernet/Wi-Fi (`en*`) interfaces, excluding VPN and loopback traffic. It reads no packet content and sends no telemetry anywhere. Initial readings and counter resets wait for a fresh delta.

**Screensaver preview** uses the shared screensaver host described above. The windowed tank suspends its animation and sampling during the presentation; the saver uses the same fish, simulation clock, and pending food. Print Monitor can now feed the fish after newly observed successful builds; see Print Monitor below.

Metal renders the tank at 30 fps with a fixed logical pixel height and the active theme's ink/paper palette. Frame timing stays outside SwiftUI observation and desktop persistence. Inactive or closed views stop animation; occluded native windows skip GPU drawing. There is no simulation catch-up after a pause. A missing GPU or shader produces an explanation in the tank. Tests cover pause/resume and feeding timing, telemetry deltas, preference persistence, and actual Metal frames for animation, feeding, activity response, and palette inversion.

## Scrapbook

Open **Scrapbook** from its desktop icon or the application menus. **New…** creates a note, command, or web link; **Edit…** changes a scrap's title and contents, or an image's caption. Save commits the edit; Cancel leaves the saved version intact. Commands remain text to copy into your own tools. Web links accept HTTP/HTTPS addresses and open only when you choose **Open Link**.

**Paste as New** (Shift-Command-V) captures the current text, web address, image, or first copied file. **Import…** adds a UTF-8 text file or image through the normal file picker. Clipboard content is read only on that explicit action; there is no background clipboard history, link fetching, or cloud sync. **Copy** (Shift-Command-C) returns the selected text or image to the clipboard. Normal copy/paste continues to work inside the editor.

Search matches every query word across titles, text, image captions, and scrap kinds, ignoring case and accents. It does not perform OCR on image pixels. **Archive** removes a scrap from the shelf; **Show Archive → Restore** brings it back. Archiving preserves both text and image files. There is no permanent-delete action in this version.

The library lives in `~/Library/Application Support/HelloMini/Scrapbook/`: a versioned `scrapbook.json` index, a `scrapbook.previous.json` copy of the previous complete index, and UUID-named PNG images. Image imports keep the first frame, apply its orientation, and limit the longest edge to 4096 pixels. These are owned snapshots, so moving or deleting an original file does not break the scrap. Text imports are limited to 1 MB, image inputs to 25 MB, and the text index to 64 MB. Back up the whole directory to retain the images as well as the index.

File work and image conversion run in an actor. Saves replace the index atomically; failed saves retain the draft and previous in-memory contents. An unreadable or future-version library opens with an error and disables writes instead of silently replacing it. Closing and reopening the window retains the model, and saved scraps survive app relaunches. Tests cover search, link validation, archive round trips, image ownership, isolated clipboard import/copy, corrupt libraries, and failed writes.


## Desk Calculator, World Clock, and Puzzle

**Desk Calculator** provides five panes: expressions, programmer arithmetic, units, timestamps, and plots. Expressions support parentheses, powers, scientific notation, pi/e, and common functions; angles use radians. General calculations use floating-point numbers. Programmer mode uses signed 64-bit integers with decimal, hexadecimal, and binary inputs, checked arithmetic overflow, bitwise operations, and shifts. Hex/binary inputs represent bit patterns; right shifts preserve the sign. Results can be selected or copied.

Unit conversion covers distance, mass, temperature, and binary byte multiples. Time conversion accepts Unix seconds or an ISO 8601 date with a timezone. Plotting samples x and y from −10 to 10, omitting undefined/out-of-range samples and breaking large jumps; it is a small plotting aid, not a symbolic algebra system. **Unreasonable mathematics** opens a decorative Metal Mandelbrot excursion. Its Control Panel switch disables this spectacle while keeping the calculator available.

**World Clock** extends `MiniClock` with saved time zones, weekday working hours, a −12…+36 hour preview, and Mac uptime. Foundation supplies timezone and daylight-saving rules. The rotating globe is deliberately stylized, not a geographic map or daylight reference. **Control Panel → Playfulness → World Clock globe** stops its rotation; Reduce Motion does too.

**Puzzle** is a 15-tile sliding puzzle shuffled through legal moves so every starting board is solvable. Tiles show a picture of Hello Mini's own window, including the puzzle. It never captures other apps or requires Screen Recording permission. **Freeze tiles** and **Refresh picture** control the image; **Live puzzle tiles** in Control Panel controls automatic one-second refreshes. Inactive, closed, or reduced-motion views stop automatic refreshes. Captures skip mouse drags and native live resizing. Native/Metal surfaces can be absent from AppKit's cached picture; the numbered puzzle remains playable.

`MiniCalculator` owns its calculation engine; `MiniPuzzle` owns its board. `MiniCore.DesktopPicture` lets the host provide window pictures without coupling Puzzle to `MiniDesktop`. The shared `MiniUI` Metal scene renderer bounds its drawable to 800 × 600 pixels, renders at 30 fps, respects theme palettes and Reduce Motion, and stops drawing when inactive or its native window is hidden. Tests cover calculation boundaries, conversions, time zones/DST, puzzle solvability, and actual Metal frames.

## Chooser, Disk First Aid, and Wastebasket

**Chooser** browses Bonjour advertisements for SSH, Screen Sharing, HTTP, or HTTPS only after **Browse**. Select a resolved service or type a hostname/IP address, then **Connect** opens the matching macOS handler. It does not scan ports or initiate connections automatically. Discovery stops when the window closes. macOS may request Local Network access; discovery errors stay visible in Chooser.

**Disk First Aid** lists mounted volumes, capacity, free space, format, and write availability. **Inspect** reads the volume's available SMART information using `diskutil info`; unsupported devices say that health is not reported. APFS volumes can share free space, so volume totals should not be summed. This is read-only inspection with no repair controls.

**Wastebasket → Scan caches** reviews the current user's Xcode DerivedData, SwiftPM cache, and Xcode cache. **Add Swift project…** adds only that project's `.build` contents to the review. The app shows names, paths, and estimated allocated sizes, with nothing selected automatically. Review selected paths in the confirmation before moving them to macOS Trash; restore mistakes through macOS Trash. There is no permanent-delete action. Close affected builds/tools first; these are rebuildable caches, but removing active caches can interrupt work.

`MiniDiskFirstAid` and `MiniWastebasket` share the `MiniStorage` actor. Scans skip symbolic links, cap traversal at 200,000 entries per item, and mark incomplete totals with **+**. Sizes are estimates and do not account for APFS sharing. Before a move, the app checks the item's root, device, inode, and symbolic-link status against the review. Changed or inaccessible items stay in the list with an error. Tests use isolated fixtures to verify traversal boundaries and replacement rejection.

## Print Monitor

**Print Monitor → Projects…** saves up to 12 GitHub or GitLab projects, including self-hosted servers. Choose a provider, enter an `owner/project` path (GitLab subgroups are supported), and choose **Add**. The **Queue** selector switches between one project and **All projects** without restarting its completion history. An existing single-project configuration migrates automatically, preserving its original Keychain account.

For GitHub Enterprise Server or GitLab Self-Managed, enable **Self-hosted server** when adding a project and enter its HTTPS website address, such as `https://git.example.com:8443`. Omit the API path: Hello Mini derives `/api/v3` for GitHub Enterprise Server and `/api/v4` for GitLab. Only installations at the website root are supported; subpath installations, HTTP, and certificate-validation bypasses are not supported. Certificates must be trusted by macOS. The server is shown in project and job details. To change it, add the project on the new server and remove the old entry; tokens are never transferred between servers.

**Branch** and **Workflow** narrow the recent builds already loaded. They match exact branch names and GitHub workflow names; selecting a workflow shows GitHub builds only. Choices come from the selected queue, with a saved choice retained even when no recent build matches. Filters persist across relaunches and queue changes; **Clear** restores all loaded builds. They do not search older history, issue extra requests, or change completion tracking and fish feeding. The printer's paper jam follows each project's latest matching build.

The app reads up to 20 recent builds per project. The combined queue labels every build with its provider and project, puts running/queued/waiting builds first, then sorts by creation date, with stable fallback ordering for missing dates. Run identities include the project, so identical numeric IDs from different sources stay separate. Each project shows its own last successful refresh and error; one failed request leaves the other queues working and retains that project's last good readings.

Automatic refresh runs while Hello Mini is running, even with Print Monitor closed. A full cycle is spaced at 90 seconds per saved project (90 seconds for one, 180 for two, and so on), with no more than three requests in flight. Fresh projects are not re-fetched just because a project was added or the window reopened. **Pause** stops automatic checks; **Refresh all** explicitly refreshes every saved project regardless of the visible queue. Repeated manual refreshes can still hit provider rate limits. Queue selection, projects, and their original path spelling survive relaunches; run snapshots and completion histories last for the app session.

Public projects can work without a token. Each saved project's **Token…** action opens an editor tied to that exact project, with explicit save and forget actions. Use GitHub Actions read access or GitLab `read_api` access. Tokens stay in this Mac's Keychain and are sent only to the configured server's HTTPS API origin, never in URLs or preferences. Removing a project keeps its token; forget it first if you want it removed. A new installation starts with no projects. Unreadable or unsupported saved libraries remain untouched and block edits instead of replacing data. Existing public-service token accounts are preserved; custom server addresses, including non-default ports, have separate token accounts.

**Jobs…** opens an on-demand job sheet for a build. It shows job states, completed durations, GitHub steps and failed-step names, or GitLab stages, reported failure reasons, and allowed failures. **Open job logs** opens the job on its provider; **Build & artifacts** opens the run page. Refresh checks the latest job attempts again, while Load more jobs fetches another page of up to 100 (500 jobs maximum). Failed requests keep previously loaded jobs visible, and closing the sheet cancels its requests. GitLab trigger jobs and child pipelines remain on the provider page. Raw logs and artifacts are not downloaded inside Hello Mini. The adapters use the [GitHub workflow jobs API](https://docs.github.com/en/rest/actions/workflow-jobs#list-jobs-for-a-workflow-run) and [GitLab pipeline jobs API](https://docs.gitlab.com/api/jobs/#list-all-jobs-by-pipeline). The printer feeds imaginary paper while builds run and reports a paper jam when any visible project's latest matching build failed; real run states remain visible. **Control Panel → Playfulness → Print Monitor paper** and Reduce Motion stop its animation.

`MiniBuildCore.BuildProvider` is the shared provider contract. `MiniGitHubCI` and `MiniGitLabCI` implement the [GitHub workflow runs API](https://docs.github.com/en/rest/actions/workflow-runs) and [GitLab pipelines API](https://docs.gitlab.com/api/pipelines/) independently of the UI. Requests use ephemeral sessions, timeouts, and same-origin HTTPS redirects, including port checks. Fixture tests cover server and project validation, run/job routing and headers, state mapping, trusted links, redirect boundaries, preference migration, and filter/completion independence. Future providers can be added without changing the desktop; the host wires completion notifications to Aquarium without either application importing the other.


## Desktop polish and build-time lunch

**Option-Command-M** opens Hello Mini's desktop launcher. Use arrows, type an application's initial, and press Return; Escape dismisses the menu. Puzzle also accepts arrow keys to move the empty space, while clicking adjacent tiles still works. Pressing Return in Print Monitor's project editor adds it; Chooser's hostname field opens the explicit connection. Utilities now explain empty states, and long CI titles/branches are constrained with their full text available on hover. CI run IDs are displayed without locale digit grouping.

The desktop supplies `miniWindowVisible` and `miniWindowActive` environment values to app content. Visibility subtracts the union of higher opaque windows after layout/stacking changes, so fully covered Aquarium, Teapot, globe, mathematical effects, live Puzzle pictures, and printer animation pause. Partially exposed accessories remain active. Aquarium also suspends its optional activity sampling while covered. Geometry is still committed only after dragging/resizing ends; visibility calculations do not add preference writes or desktop state changes to each pointer movement.

**Control Panel → Playfulness → Feed fish after successful builds** is enabled by default. When Print Monitor receives a successful refresh, newly successful builds cause one food drop per batch and an Aquarium note such as “A build passed. Lunch is served.” Ordinary manual feeding remains available. Aquarium need not be open: it remembers the latest meal until its renderer next runs. Paused/reduced-motion tanks retain the food without forcing motion.

The first successful refresh for each project after launch or re-adding it establishes a baseline and does not feed from old history. Later refreshes detect transitions to success and newer successful run IDs, including builds that finish between polls. Repeated refreshes and repeated successes for the same retained run ID do not feed again. Each saved project retains its own tracker of the latest 200 observed IDs during the app session. Switching the visible queue preserves all trackers; removing a project discards its tracker, and relaunching establishes fresh baselines. Successful responses in one refresh cycle produce one combined food drop. Failed requests do not change this history. The host polls while Hello Mini is running, including with Print Monitor closed or the native app inactive. Pause in Print Monitor suspends automatic polling. Relaunch establishes fresh completion baselines.

Turning off the feeding switch or Extra silliness consumes notifications without feeding; re-enabling it does not replay missed meals. `MiniBuildCore.BuildCompletionTracker` handles deduplication, Print Monitor emits an injected completion callback, and the executable connects it to Aquarium. Tests exercise provider JSON through that callback to the Aquarium feeding state, including duplicate polls, retries, batching, source changes, and both switches, as well as window coverage and keyboard puzzle boundaries.


## New in the 0.2.0 development build

**Control Panel → Playfulness → System sounds** controls original synthesised startup, jam, feeding, cleanup, and alarm cues. Extra silliness and normal macOS output volume/mute apply. The menu bar printer reports the latest build across every saved project, independent of visible queue filters; hover for refresh errors or pause state. Click it to open Print Monitor. The thermometer reports thermal state rather than degrees. Aqua dock tiles show attention badges, optionally magnify on hover, and bounce twice when an application is newly opened from the dock or a menu. **Control Panel → Playfulness → Dock launch bounce** controls the cue; Reduce Motion, inactive desktops, and screensavers suppress it. Restoring a saved session or activating an already-open app does not bounce.

**Clear jam…** on a failed build opens a retry dialog. GitHub retries failed jobs and their dependents through its [failed-job rerun endpoint](https://docs.github.com/en/rest/actions/workflow-runs#re-run-failed-jobs-from-a-workflow-run); GitLab's [pipeline retry endpoint](https://docs.gitlab.com/api/pipelines/#retry-jobs-in-a-pipeline) retries failed and cancelled jobs. Tokens need Actions write access on GitHub or API scope and pipeline retry permission on GitLab. **Copies** means up to three attempts, defaulting to one. Further copies wait for an observed active attempt to fail; success, cancellation, a missing run, uncertain responses, or a 30-minute wait limit stop the sequence. Closing the dialog stops remaining copies; submitted jobs continue on the provider. Write requests never follow redirects or automatically repeat after an error.

**Edit → Show Clipboard** opens an on-demand text/image snapshot. **File → Capture Desktop to Scrapbook** saves an image of Hello Mini's own desktop without touching the clipboard. Command-Shift-3 works when delivered to Hello Mini; macOS may reserve that shortcut, so the menu command is the reliable alternative. Capture errors appear in Scrapbook or the desktop.

**Special → Empty Wastebasket…** opens the existing cache review; only explicitly selected items move to macOS Trash. **Restart** relaunches Hello Mini, and **Shut Down** quits it. System 7's optional menu blink flashes a chosen command three times. **Help → Show Balloon Help** enables explanations for controls with help text; native tooltips and accessibility hints remain available. Motion effects respect Reduce Motion.

**Key Caps** offers a fixed US keyboard with Shift, a curated symbol/emoji palette, arbitrary Unicode text to copy, and a button for the native macOS character viewer. **Alarm Clock** has timers from 1 minute to 24 hours, 25-minute focus sessions, and 5-minute breaks. Each session starts explicitly. Timers use saved wall-clock deadlines: sleep counts, overdue alarms fire on wake or next launch, and a ringing alarm remains visible until dismissed. The menu bar alarm works with the accessory closed and remains steady when motion is disabled.

**Find File**, also available through Finder's **Find…** button or Command-F, searches indexed file names within your home folder or a chosen folder. It shows up to 200 results with explicit Open/Reveal actions. Spotlight indexing and macOS access permissions determine which files appear; this is not a full disk traversal. **Control Panel → Appearance → Desktop Pattern** supplies a saved 8 × 8 pixel editor with immediate desktop preview, Clear, and Reset to theme.

Genie minimisation, other physical keyboard layouts, and full release validation remain on the roadmap.


## License

Hello Mini is [MIT licensed](LICENSE). Imported teapot data retains its original permission notice; see [third-party notices](THIRD_PARTY_NOTICES.md). Both notices ship inside the app bundle.
