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

The initial goal is a black-and-white version that targets the early black-and-white Mac OS era. Future theme directions include System 7 and early Aqua, specifically the Mac OS X 10.0 era with its pinstripes. These are future visual themes, not part of the current implementation.


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

The desktop opens at 1280 × 720. Use View → Enter / Exit Full Screen (or Control-Command-F) for a dedicated display. Drag the striped title bars to move windows, or the bottom-right corner grips to resize them. Grips also expose accessibility increment/decrement actions. Each app supplies a minimum size; windows stay inside the available desktop. The Window menu reopens closed windows and **Reset Window Layout** restores their default positions and sizes.

Open applications, stacking order, positions, and sizes are saved automatically and restored after the startup sequence. A deliberately empty desktop stays empty. On a first launch, Activity Monitor opens by default. Layouts adapt to the current display without overwriting the saved geometry until you move or resize a window. Unknown application IDs are ignored, and unreadable or unsupported session data falls back to the initial layout.

At launch, a brief Macintosh boot homage shows a happy Mac, then “Welcome to Macintosh.” with a stepped progress bar and a row of startup icons. It uses the selected theme and lasts about four seconds before opening the desktop. Click **Skip startup** or press Escape to enter immediately. **Control Panel → Playfulness → Macintosh startup** disables it for subsequent launches; the Extra silliness master switch and macOS Reduce Motion also bypass it. This is a silent presentation, not a measure of system boot or application loading. Desktop windows and their input handlers are created afterward. The sequence runs once per launch and does not replay when changing themes, focusing the app, or reopening an application window.

The desktop menu bar uses custom monochrome dropdowns with checkmarks, disabled commands, and shortcut labels. Click a heading to open it, then move across headings to switch menus. Arrow keys navigate, Return activates the selected command, and Escape or a click outside dismisses the menu. Command shortcuts also work while menus are closed; native folder dialogs retain their normal keyboard behavior.

The Finder browses real folders, with icon and list views, back/up navigation, hidden-file visibility, and a folder chooser. Its last folder, icon/list mode, and hidden-file preference survive relaunches; navigation history starts fresh. Missing or inaccessible restored folders use the normal error view and folder chooser. Double-click a folder to browse it or a file to open it with its default macOS application. Right-click an item to reveal it in macOS Finder. Folder access follows normal macOS permissions; errors appear in the window. This first version does not modify, move, or delete files.

## Applications and architecture

Each application is its own SwiftPM target, depending on `MiniCore` and the shared `MiniUI` controls. `MiniCore` defines the `MiniApplication` contract and command descriptions. `MiniDesktop` owns application launching, window positions, focus, stacking, and menu rendering; it does not import any application target. `HelloMini` registers the application instances and chooses which open at startup.

`MiniDesktop` saves a versioned session in local app preferences, keyed by stable application IDs. Geometry is committed when a drag or resize ends; tracking uses a fixed desktop coordinate space and does not write preferences on every pointer update. Application-specific preferences remain inside their own modules. `MiniApplication.minimumSize` defaults to the app's default size, and apps with flexible content can provide smaller limits. Finder currently stores its last folder as a local path; an eventual App Sandbox distribution will need scoped-bookmark access restoration as part of that packaging work.

- `MiniFinder` owns directory reading, navigation history, and the Finder interface.
- `MiniActivityMonitor` shows local CPU usage and a two-minute graph, memory statistics, load averages, uptime, disk free space on the home volume, and processes. It opens at startup for the CI display. Updates run off the UI actor every two seconds while the window is open, with pause/resume, name/PID filtering, and CPU or memory sorting.
- `MiniClock` supplies both Clock (local/UTC time and a monotonic stopwatch) and World Clock (saved time zones, working hours, and a decorative globe). A running stopwatch continues counting while its window is closed.
- `MiniControlPanel` provides Appearance and Playfulness panes, with live theme previews and saved effect switches. Classic uses the original dotted desktop, Paper uses a plain white desktop, and Midnight uses white ink on black. Select a preview or use the app's Appearance menu; the choice applies immediately and persists across launches.
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

Themes are registered values with stable string IDs, rather than a closed enum. `HelloMiniApp` owns the `MiniThemeRegistry` and gives its metadata to `AppearanceSettings`, and the same registry to the desktop and Control Panel. Control Panel discovers every registered theme automatically and its scrollable previews use the real shared renderers. The existing `classic`, `paper`, and `midnight` preference IDs are preserved; unavailable themes fall back to Classic (or the first registered theme) without erasing the saved preference.

A future `MiniSystem7Theme` or `MiniAquaTheme` SwiftPM target can depend on `MiniCore` and `MiniUI`, export a `MiniThemeDefinition`, and be added to that registry. No application or desktop behavior needs an era-specific switch. Definitions provide:

- Semantic foreground, background, accent, and selection colors; body, small, title, and display fonts.
- Solid, gradient, dotted, pinstriped, bundled-image, and custom SwiftUI surfaces.
- Active/inactive window frames, corner radii, borders, shadows, title-bar height, and menu dimensions and surfaces.
- Optional title-bar, button, and semantic-icon renderers for artwork and controls that cannot be expressed by tokens alone. Title bars receive the window title, active state, and close action; buttons receive pressed/enabled state and their original label. Custom renderers must retain those actions and accessibility labels.

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

`MiniUITests` exercises an unshipped color theme with pinstripes, gradients, rounded frames, custom renderers, and a bundled image; it also checks actual rendered pixels for each surface type. System 7 and Aqua themselves remain future designs.

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

**Print Monitor** treats software builds as a print queue. Choose **GitHub** or **GitLab**, enter an `owner/project` path (GitLab subgroups are supported), and press **Load**. The app reads the latest 20 GitHub Actions runs or GitLab.com pipelines, shows their real states, and refreshes every 90 seconds while Hello Mini is active and the window is open. **Pause** stops automatic refresh; **Refresh** checks immediately. Failed requests retain the previous readings and their update time, with an error alongside them.

Public projects can work without a token. **Token…** lets you explicitly save or forget an optional per-provider, per-project token in this Mac's Keychain. Use GitHub Actions read access or GitLab `read_api` access. Tokens are sent only to the selected provider's fixed HTTPS API host, never in URLs or preferences. Project/provider preferences survive relaunches; no project is configured by default. This first version supports github.com and gitlab.com, not self-hosted service URLs.

**Build & artifacts** opens that run's provider page for logs and artifact downloads. Job details and artifact downloads inside Hello Mini remain future work. The printer feeds imaginary paper while builds run and reports a paper jam for the newest failed build; real run states remain visible. **Control Panel → Playfulness → Print Monitor paper** and Reduce Motion stop its animation.

`MiniBuildCore.BuildProvider` is the shared provider contract. `MiniGitHubCI` and `MiniGitLabCI` implement the [GitHub workflow runs API](https://docs.github.com/en/rest/actions/workflow-runs) and [GitLab pipelines API](https://docs.gitlab.com/api/pipelines/) independently of the UI. Requests use ephemeral sessions, timeouts, and same-host HTTPS redirects. Fixture tests cover project validation, provider state mapping, and trusted build-page URLs. Future providers can be added without changing the desktop; the host wires completion notifications to Aquarium without either application importing the other.


## Desktop polish and build-time lunch

**Option-Command-M** opens Hello Mini's desktop launcher. Use arrows, type an application's initial, and press Return; Escape dismisses the menu. Puzzle also accepts arrow keys to move the empty space, while clicking adjacent tiles still works. Pressing Return in Print Monitor's project field loads it; Chooser's hostname field opens the explicit connection. Utilities now explain empty states, and long CI titles/branches are constrained with their full text available on hover. CI run IDs are displayed without locale digit grouping.

The desktop supplies `miniWindowVisible` and `miniWindowActive` environment values to app content. Visibility subtracts the union of higher opaque windows after layout/stacking changes, so fully covered Aquarium, Teapot, globe, mathematical effects, live Puzzle pictures, and printer animation pause. Partially exposed accessories remain active. Aquarium also suspends its optional activity sampling while covered. Geometry is still committed only after dragging/resizing ends; visibility calculations do not add preference writes or desktop state changes to each pointer movement.

**Control Panel → Playfulness → Feed fish after successful builds** is enabled by default. When Print Monitor receives a successful refresh, newly successful builds cause one food drop per batch and an Aquarium note such as “A build passed. Lunch is served.” Ordinary manual feeding remains available. Aquarium need not be open: it remembers the latest meal until its renderer next runs. Paused/reduced-motion tanks retain the food without forcing motion.

The first successful refresh after launch or switching projects establishes a baseline and does not feed from old history. Later refreshes detect transitions to success and newer successful run IDs, including builds that finish between polls. Repeated refreshes and repeated successes for the same retained run ID do not feed again. The tracker remembers the latest 200 observed IDs for the current source during the app session; relaunching or changing source establishes a fresh baseline. Failed requests do not change this history. Print Monitor must be open and checking (or manually refreshed); this adds no background CI watcher.

Turning off the feeding switch or Extra silliness consumes notifications without feeding; re-enabling it does not replay missed meals. `MiniBuildCore.BuildCompletionTracker` handles deduplication, Print Monitor emits an injected completion callback, and the executable connects it to Aquarium. Tests exercise provider JSON through that callback to the Aquarium feeding state, including duplicate polls, retries, batching, source changes, and both switches, as well as window coverage and keyboard puzzle boundaries.


## License

Hello Mini is [MIT licensed](LICENSE). Imported teapot data retains its original permission notice; see [third-party notices](THIRD_PARTY_NOTICES.md). Both notices ship inside the app bundle.
