# Hello Mini

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

TBC. App Store likely makes the most sense but some of the capabilities required and the user audience may mean homebrew is a better channel. 

## But Why, Though? 

Because charm is sometimes more important than practicality.  And because it is a challenge to see what can be done.

## Running the first desktop

Requires macOS 26 and Xcode 26.6 or another toolchain with Swift 6.3+.

```sh
make run     # Build a local app bundle and launch it
make check   # Check formatting, run Swift Testing, and build
make format  # Apply swift-format
```

Open `Package.swift` in Xcode to work on the package. `make app` produces `dist/Hello Mini.app` with a local ad-hoc signature; distribution signing and notarization are not configured yet.

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
- `MiniClock` shows local or UTC time and a monotonic stopwatch. A running stopwatch continues counting while its window is closed.
- `MiniControlPanel` provides Appearance and Playfulness panes, with live theme previews and saved effect switches. Classic uses the original dotted desktop, Paper uses a plain white desktop, and Midnight uses white ink on black. Select a preview or use the app's Appearance menu; the choice applies immediately and persists across launches.
- `MiniAbout` shows application and system information.

`AppearanceSettings` in `MiniCore` stores the selected theme in the app's preferences and falls back to Classic if a saved theme is unavailable. The executable shares one settings instance with the desktop and Control Panel. `MiniUI` supplies `MiniThemeDefinition`, the theme registry, and the `miniTheme` environment value used by windows, menus, icons, and app content. Themes affect Hello Mini's appearance, not the Mac's system-wide appearance. Theme changes keep open applications and their state intact.

Launch apps from their desktop icons, the Macintosh menu, or Window. The active application supplies its own menus. Closing Activity Monitor stops its sampling task; reopening resumes unless it was paused. Resuming begins a fresh CPU history rather than presenting old readings as recent. All applications are currently compiled into the executable; external plugin loading remains undecided.

Activity Monitor's system CPU percentage is the difference between kernel CPU tick counters, normalized across all cores. Its first reading needs two samples. Process CPU comes from `ps` and can exceed 100% for multithreaded processes; process memory is RSS, which can include shared pages. These values do not sum to the system totals. Memory shows wired, compressed, and free physical pages separately, not a memory-pressure estimate. No process termination controls are included. Only executable names are read, never command arguments. This monitors the local Mac, not CI workflow or job status.

The current build requires macOS 26; macOS 15 compatibility has not been validated.

## Public release direction

The aim is a public GitHub project that other people can install and enjoy, with distribution channels such as Homebrew to be evaluated later. Build CI is configured; distribution signing, notarization, release publishing, and the final distribution channel remain future work. CI status integrations are deferred: when added, they should support commonly used services through provider modules, with per-user configuration, rather than assuming one private CI installation. The Aquarium screensaver remains the next planned playful addition after the desktop improvements.

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

The first working switch is **Teapot animation**. It stops automatic rotation in an already-open Teapot window, retaining manual orbit, shading modes, and the app's own pause/resume choice. Re-enabling it does not open Teapot or undo a manual pause. Reduce Motion still prevents automatic rotation.

`PlayfulnessSettings` and `MiniPlayfulEffect` live in `MiniCore`. Effect modules export metadata with stable IDs; `HelloMiniApp` registers implemented effects and injects one shared settings instance into Control Panel and the modules that use it. Control Panel discovers these switches automatically. Renderers check `allows(id)` before scheduling their effects and also honor Reduce Motion and their own visibility/lifecycle rules. Removed modules cannot run through the settings catalog, but their saved choices survive reinstallation. Theme modules supply appearance, not effect preferences.

The Playfulness pane also lists the future ideas explicitly as planned: fluid **Living dither**, particle-based **Impossible instruments**, folding **Physical windows**, and stippled 3D **Depth behind glass**. These renderers are not implemented yet; each will receive its own working switch when registered.

**After Dark–inspired screensavers** are also on the drawing board: an **Aquarium** with wandering fish and bubbles, and **Flying toasters** with winged appliances and passing toast. They are candidates for extravagant GPU animation expressed through the current theme's palette and artwork. Both will be optional through Control Panel and the shared Playfulness settings. Their presentation, idle activation, and packaging can be decided later; no screensaver renderer or idle behavior is implemented yet.
