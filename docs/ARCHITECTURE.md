# Architecture

The baseline is macOS 26 and Swift 6.4, using SwiftUI, AppKit, Metal, Swift Testing, and `swift-format`. This guide describes the released architecture; external binary plugins and macOS 15 compatibility remain future decisions.

[Contributing](../CONTRIBUTING.md) · [User guide](USER_GUIDE.md) · [Build CI](CI.md) · [Releasing](RELEASING.md)

## Modules and ownership

Applications live in SwiftPM targets, depending on `MiniCore` and the shared `MiniUI` controls. `MiniCore` defines the `MiniApplication` contract and command descriptions. `MiniDesktop` owns application launching, window positions, focus, stacking, and menu rendering; it does not import any application target. `HelloMini` registers the application instances and chooses which open at startup.

`MiniDesktop` saves a versioned session in local app preferences, keyed by stable application IDs. Geometry is committed when a drag or resize ends; tracking uses a fixed desktop coordinate space and does not write preferences on every pointer update. Application-specific preferences remain inside their own modules. `MiniApplication.minimumSize` defaults to the app's default size, and apps with flexible content can provide smaller limits. Finder currently stores its last folder as a local path; an eventual App Sandbox distribution will need scoped-bookmark access restoration as part of that packaging work.

An application can expose more than one desk accessory: `MiniClock` supplies Clock, Alarm Clock, and World Clock. `MiniAccessories` supplies Clipboard and Key Caps; `MiniFinder` owns Finder, labels, and Spotlight-backed Find File. `MiniScreensaver` hosts Aquarium, Flying Toasters and Scrapbook Slideshow. `MiniStorage` supports Disk First Aid and Wastebasket. `MiniBuildCore` defines provider and completion contracts; `MiniGitHubCI` and `MiniGitLabCI` implement them, and `MiniPrintMonitor` presents the queues. The target graph in [Package.swift](../Package.swift) is authoritative.

Keep application-to-application connections injected by `HelloMini`. For example, Print Monitor emits a completion callback and the executable connects it to Aquarium, without either application importing the other. All modules are currently bundled into one executable.

## Theme framework

Themes are registered values with stable string IDs, rather than a closed enum. `HelloMiniApp` owns the `MiniThemeRegistry` and gives its metadata to `AppearanceSettings`, and the same registry to the desktop and Control Panel. Control Panel discovers every registered theme automatically and its scrollable previews use the real shared renderers. The appearance strip has a persistent horizontal scrollbar, independent of macOS overlay-scrollbar preferences. The existing `classic`, `paper`, and `midnight` preference IDs are preserved; unavailable themes fall back to Classic (or the first registered theme) without erasing the saved preference.

`MiniSystem7Theme`, `MiniPlatinumTheme` and `MiniAquaTheme` each depend on `MiniCore` and `MiniUI`, export a `MiniThemeDefinition`, and are added by the executable to the shared registry. No application or desktop behavior needs an era-specific switch. Definitions provide:

- Semantic foreground, background, accent, and selection colors; body, small, title, and display fonts. Optional desktop text colors, label surfaces, and text shadows allow readable labels over a coloured wallpaper without changing window content.
- Solid, gradient, dotted, pinstriped, bundled-image, and custom SwiftUI surfaces.
- Active/inactive window frames, corner radii, borders, shadows, title-bar height, and menu dimensions and surfaces. An optional dock frame enables the shared dock and reserves its desktop area; themes supply styling while the shell owns launching and restoring. A `windowShade` flag lets a theme offer window shade, whose state the shell also owns.
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

`MiniUITests` exercises an unshipped color theme with pinstripes, gradients, rounded frames, custom renderers, and a bundled image; it also checks actual rendered pixels for each surface type. The shipped System 7 and Aqua modules test selection persistence, rendered active/inactive chrome, and coloured/selected icons. Aqua additionally checks traffic-light colour ordering, disabled controls, gel-button states, periodic pinstripes, and distinct artwork for all 15 semantic icons. Desktop tests cover minimise/focus restoration, zoom geometry across display sizes, and compatibility with existing saved sessions. The era-specific theme modules use original artwork and system fonts rather than bundling Apple artwork or fonts.

## Display presentation

`AppearanceSettings` persists tiny-screen mode independently of the theme and makes it mutually exclusive with Purist mode. `MiniDisplayViewport` divides the available dimensions by the selected scale (2× by default, optionally 1.5×), then scales that logical layout for presentation. Standard mode remains 1× and Purist mode remains a fixed 512 × 384 canvas. The existing desktop coordinate space, window constraints, and minimum-content scrolling continue to operate in logical points. Switching display modes does not commit new window placements.

`MiniUI.MiniDisplayContext`, exposed as `@Environment(\.miniDisplay)`, communicates presentation scale and logical desktop size. Themes keep their existing fonts and dimensions; neither theme renderers nor app views should multiply them by this scale. Applications use available layout size to reflow content. Native sheets escape the desktop transform, so custom sheet content uses `miniSheet(width:)` once per sheet to enlarge its content and bound its scrolling viewport. Native system panels, alerts, and menus retain OS sizing.

The screensaver's separate native window applies the same scale to its own screen area. Both display hosts use `miniScreenEdges()` after scaling to preserve the inset bevel and rounded corners in full screen. Desktop capture continues to capture the native content view at its backing resolution, including the presented UI and screen edges; it does not export the smaller logical canvas. See the [tiny-screen design](TINY_SCREEN_MODE.md) for implementation details and follow-up validation.

## Effects and screensavers

`PlayfulnessSettings` and `MiniPlayfulEffect` live in `MiniCore`. Effect modules export metadata with stable IDs; `HelloMiniApp` registers implemented effects and injects one shared settings instance into Control Panel and the modules that use it. Control Panel discovers these switches automatically. Renderers check `allows(id)` before scheduling their effects and also honor Reduce Motion and their own visibility/lifecycle rules. Removed modules cannot run through the settings catalog, but their saved choices survive reinstallation. Theme modules supply appearance, not effect preferences.

`MiniCore` owns saver metadata and preferences. `MiniScreensaver` owns presentation, idle timing, and input handling; registered definitions supply content and optional start/stop hooks. `MiniToasters` registers the toaster effect and renderer. The executable wires Aquarium into the same registry without an Aquarium dependency on the screensaver host. Covered desktop graphics pause through the desktop visibility environment, while window positions, editors, and application models stay intact.

## Graphics lifecycle

The desktop supplies `miniWindowVisible` and `miniWindowActive` environment values to app content. Visibility subtracts the union of higher opaque windows after layout/stacking changes, so fully covered Aquarium, Teapot, globe, mathematical effects, live Puzzle pictures, and printer animation pause. Partially exposed accessories remain active. Aquarium also suspends its optional activity sampling while covered. Geometry is still committed only after dragging/resizing ends; visibility calculations do not add preference writes or desktop state changes to each pointer movement.

`MiniCalculator` owns its calculation engine; `MiniPuzzle` owns its board. `MiniCore.DesktopPicture` lets the host provide window pictures without coupling Puzzle to `MiniDesktop`. The shared `MiniUI` Metal scene renderer bounds its drawable to 800 × 600 pixels, renders at 30 fps (15 fps while Hello Mini is in the background), respects theme palettes and Reduce Motion, and stops drawing when its native window is hidden. Tests cover calculation boundaries, conversions, time zones/DST, puzzle solvability, and actual Metal frames.

Teapot’s Metal renderer handles geometry, lighting, specular highlights, depth testing, and dithering. The Bézier control net is tessellated once when the view is created and uploaded to GPU buffers; per-frame updates send only camera and palette uniforms. The view targets 60 fps while Hello Mini is frontmost and 30 fps in the background, pauses when its window is hidden or covered, and releases its draw delegate when closed. Reduce Motion disables automatic rotation while retaining manual orbit controls. No GPU is required for the rest of the desktop; this app shows an explanation if Metal initialization fails.

Aquarium renders its tank at 30 fps with a fixed logical pixel height and the active theme's ink/paper palette. Frame timing stays outside SwiftUI observation and desktop persistence. Closed or hidden views stop animation, including covered windows and sleeping displays; the tank keeps swimming at 15 fps while another app has focus. `MiniMetalView` owns this policy for every Metal accessory, and `AnimationClock` wraps simulation time once a day so 32-bit shader uniforms never freeze. There is no simulation catch-up after a pause. A missing GPU or shader produces an explanation in the tank. Tests cover pause/resume and feeding timing, telemetry deltas, preference persistence, and actual Metal frames for animation, feeding, activity response, and palette inversion.

## Persistence and file operations

Scrapbook file work and image conversion run in an actor. Saves replace the index atomically; failed saves retain the draft and previous in-memory contents. An unreadable or future-version library opens with an error and disables writes instead of silently replacing it. Closing and reopening the window retains the model, and saved scraps survive app relaunches. Tests cover search, link validation, archive round trips, image ownership, isolated clipboard import/copy, corrupt libraries, and failed writes.

`MiniDiskFirstAid` and `MiniWastebasket` share the `MiniStorage` actor. Scans skip symbolic links, cap traversal at 200,000 entries per item, and mark incomplete totals with **+**. Sizes are estimates and do not account for APFS sharing. Before a move, the app checks the item's root, device, inode, and symbolic-link status against the review. Changed or inaccessible items stay in the list with an error. Tests use isolated fixtures to verify traversal boundaries and replacement rejection.

User-facing data locations and backup guidance are in [Installation](INSTALL.md#updates-and-your-data) and [Scrapbook](USER_GUIDE.md#scrapbook). Preserve stable application, theme, and effect IDs when changing stored formats.

## CI providers and completion tracking

`MiniBuildCore.BuildProvider` is the shared provider contract. `MiniGitHubCI` and `MiniGitLabCI` implement the [GitHub workflow runs API](https://docs.github.com/en/rest/actions/workflow-runs) and [GitLab pipelines API](https://docs.gitlab.com/api/pipelines/) independently of the UI. Requests use ephemeral sessions, timeouts, and same-origin HTTPS redirects, including port checks. Fixture tests cover server and project validation, run/job routing and headers, state mapping, trusted links, redirect boundaries, preference migration, and filter/completion independence. Future providers can be added without changing the desktop; the host wires completion notifications to Aquarium without either application importing the other.

The first successful refresh for each project after launch or re-adding it establishes a baseline and does not feed from old history. Later refreshes detect transitions to success and newer successful run IDs, including builds that finish between polls. Repeated refreshes and repeated successes for the same retained run ID do not feed again. Each saved project retains its own tracker of the latest 200 observed IDs during the app session. Switching the visible queue preserves all trackers; removing a project discards its tracker, and relaunching establishes fresh baselines. Successful responses in one refresh cycle produce one combined food drop. Failed requests do not change this history. The executable owns background polling while Hello Mini runs, including with Print Monitor closed or the native app inactive. Pause in Print Monitor suspends automatic checks. Relaunch establishes fresh completion baselines.

Turning off the feeding switch or Extra silliness consumes notifications without feeding; re-enabling it does not replay missed meals. `MiniBuildCore.BuildCompletionTracker` handles deduplication, Print Monitor emits an injected completion callback, and the executable connects it to Aquarium. Tests exercise provider JSON through that callback to the Aquarium feeding state, including duplicate polls, retries, batching, source changes, and both switches, as well as window coverage and keyboard puzzle boundaries.

## App icon

The Dock and Finder icon uses the same pixel Macintosh artwork as the desktop. `make icons` generates all ten standard/Retina icon representations (16 through 1024 pixels), `Support/AppIcon.icns`, and a 1024-pixel preview at `Support/AppIcon.png`. Small icons use the pixel silhouette directly; larger icons sit on a white tile. Edit the computer artwork in `Sources/MiniUI/PixelSymbol.swift` or the rendering in `scripts/GenerateIcons.swift` to update it. App builds regenerate changed artwork and copy the icon into the bundle before signing.

## Communications telemetry

`MiniCommunications` owns a versioned station profile, bounded Prometheus query client, timestamp-based channel state, and session-only log. The host polls it independently of window visibility and injects optional sound cues. Disconnect/reconfiguration cancels requests and changes a generation token so late responses cannot repopulate a different station. Credentials use a separate Keychain service keyed by the exact endpoint, and profiles never contain them. Query history lives in the backend; the accessory requests one hour only when a chart is selected. The [MotionStudies example](../examples/communications/README.md) translates the existing observer response outside the app, preserving original evidence timestamps and leaving feed business rules with the observer.


## Drawing, presets and portable scraps

`MiniPaint` keeps a bounded monochrome bitmap and 20-step pixel/selection operation history, writes the current drawing atomically after each completed edit, and exports an original-resolution PNG. The host injects its Send to Scrapbook connection; the painting module does not import Scrapbook. Desktop presets belong to `MiniDesktop`, compose appearance values with a desktop-session snapshot, and minimise extra open windows instead of destroying their views. Scrapbook's actor owns backup encoding, validation, duplicate fingerprints and staged image writes; an explicit preview precedes the index commit, with rollback of only newly created images on failure.


The `MiniNetwork` module owns its path monitor and a serial-queue TCP probe. Probe completion, cancellation, timeout, and stale callbacks are serialized; the main-actor model uses request IDs to discard late UI results. It sends no application payload and does not persist destinations or log entries. Finder metadata and bounded preview reads run on `DirectoryReader`. Desktop session recovery preserves original bytes before enabling layout writes again. Scrapbook recognition yields to user edits through busy-state transitions, with generation IDs invalidating cancelled work.


Build history and artifact metadata extend the provider protocol with conservative defaults for other providers. Each provider derives download endpoints from its validated server/project and numeric artifact identifier rather than trusting remote URLs. `ArtifactDownload` uses a dedicated ephemeral session, strips all headers on cross-origin redirects, bounds received bytes, validates ZIP headers and applies quarantine before committing to a new path. Finder operations stage bounded copies and use exclusive rename on commit. Network probe transports/deadlines are injectable for deterministic failure tests. Control-frame preferences expose geometry only for targeted regression assertions.

Provider references: [GitHub artifacts](https://docs.github.com/en/rest/actions/artifacts?apiVersion=2022-11-28), [GitLab job artifacts](https://docs.gitlab.com/api/job_artifacts/), and [GitLab jobs](https://docs.gitlab.com/api/jobs/).

## Transfers and desktop effects

Finder copies stream regular files in 256 KB chunks into an owned staging directory, checking cancellation and limits during transfer. Special files are refused, symlinks remain links, and metadata is copied without following symlinks. Source identity/size/modification changes fail before the exclusive commit. Move uses `RENAME_EXCL`; an `EXDEV` failure leaves the source intact instead of attempting copy-and-delete. No destination replacement is implemented.

Preset transfer reuses the versioned, bounded document validation and requires explicit import review. Imports never apply layouts, replace existing presets or close documents. Living dither uses a bounded Canvas grid at up to 12 Hz, with no hit testing or accessibility nodes, and pauses for Reduce Motion, inactive scenes, desktop occlusion and display sleep.


## Organisation, history and presentation

Scrapbook schema 2 adds optional collection/favourite metadata and a bounded named-collection list. Schema 1 remains readable; the first successful migration retains its original index as scrapbook.v1.json. Save validation refuses unknown versions before writing images or replacing the index. Portable archive schema 2 retains empty collections and organisation; schema 1 imports remain supported. Content fingerprints include organisation so imports do not silently discard differing filing/favourite choices.

CalculatorApplication owns a persistent CalculatorModel with a versioned, bounded 50-entry expression history. Pane views and conversion/plot helpers live in separate source files. Bad/future history bytes remain untouched until explicit reset, which retains a previous copy. The host injects the asynchronous Scrapbook handoff; the Calculator module does not import Scrapbook. Result provenance follows the last successful calculation rather than the current editable field.

Depth behind glass uses a small SwiftUI Canvas projection of three wireframe cubes, with bounded stippling and a 12 fps TimelineView. It consumes theme ink/paper and shared motion/desktop visibility/suspension state, with native occlusion and screen-sleep notifications. No renderer runs continuously while gated. Sheet dismissal uses the event-driven focus coordinator described below.


## Filing, Redo and focus coordination

ScrapbookModel exposes module-local state to focused filing, transfer and OCR coordination extensions. Batch operation IDs intersect the explicit selection with the current visible filter. Each filing transaction saves before updating memory; its session-only inverse records organisation metadata and collection names. Undo verifies expected filing state and restores only that metadata, preserving text/OCR. The actor validates a pre-existing version-1 migration backup as a regular, bounded, non-symlink compatible file before accepting it.

Finder Redo is captured after successful Undo. Rename/Move use a fresh inverse receipt and the same exclusive guarded rename path; New Folder records parent identity and uses exclusive creation. Successful Redo creates a fresh Undo receipt; new successful operations clear Redo. Unsupported snapshots leave no receipt without reporting a successful filesystem mutation as failure.

MiniSheetFocusRestoration attaches to the presenting native window. Requests wait for sheet-end/key-window/update events and a main-queue event barrier, with generation cancellation on deactivation/dismantling. Finder and Scrapbook supply their own destination focus; no fixed 250–300 ms delays remain. Paper shuffle uses a finite 0.33-second keyframe rotation, defaults off and reads shared motion/activity gates.


## MiniPaint drawing and recovery

PaintApplication registers commands and receives host connections. PaintView owns presentation/focus; PaintToolbar and PaintCanvas keep layout and gesture conversion separate. PaintShapes and PaintSelectionOperations rasterise into the fixed monochrome bitmap. Shape previews rebuild from the gesture-start snapshot, then commit as one edit; cancellation restores it. Gesture completion is observable even when a selection-only gesture changes no pixels, so command availability updates immediately. Selection transforms read immutable input for overlap safety, and Undo/Redo snapshots retain selection geometry.

PaintStore retains the version-one drawing format. Loads validate bounded size, version and binary pixels; save revalidates the existing on-disk document before atomic replacement. Bad/future data blocks writes, while failed saves retain the current drawing and history in memory for PNG export. Native export and picture-import dismissal use the shared event-driven focus helper. Marching ants uses an eight-fps TimelineView with a static fallback and motion, accessory visibility/activity, desktop suspension, scene, occlusion and display-sleep gates. Its black/white border retains contrast over both ink and paper.

Key Caps uses an NSView-scoped local AppKit event monitor. It returns events unchanged, observes only its own key native window while the accessory is active/visible and the desktop/scene is active, and removes monitoring on dismantling. It stores only the currently held physical key codes/modifier flags in view state. Preset persistence is separate from its view; desktop wallpaper/pattern rendering is separate from window coordination.
