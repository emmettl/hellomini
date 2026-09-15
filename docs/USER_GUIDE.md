# Using Hello Mini

This guide describes the **0.4.0** app. Later work is tracked separately in the [roadmap](../ROADMAP.md).

[Install or update](INSTALL.md) · [Desktop](#desktop-and-keyboard-controls) · [Appearance](#appearance-and-aqua-dock) · [Print Monitor](#print-monitor) · [Scrapbook](#scrapbook) · [Screensavers](#screensavers)

Launch apps from desktop icons, the Aqua dock, the Macintosh menu, or Window. **Option-Command-M** opens the desktop launcher: use arrows or an application's initial, then Return. Escape dismisses it. Desktop icons scroll when the application list is taller than the display. Control Panel changes apply immediately and are saved.

## Desktop and keyboard controls

The desktop opens at 1280 × 720. Use View → Enter / Exit Full Screen (or Control-Command-F) for a dedicated display. Drag the striped title bars to move windows, or the bottom-right corner grips to resize them. Grips also expose accessibility increment/decrement actions. Each app supplies a minimum size; windows stay inside the available desktop. 

The Window menu reopens closed windows and **Reset Window Layout** restores their default positions and sizes. 

Aqua adds working red **Close**, yellow **Minimise**, and green **Zoom** controls, with hover symbols and inactive grey states. Zoom fills the available desktop and toggles back to the previous geometry; dragging or resizing a zoomed window establishes a new normal size. Minimise keeps the application and its view state alive, hides the window, and gives focus to the next visible window. In Aqua, **Control Panel → Playfulness → Genie minimise** pours the window into the dock and back out again; turning the switch off or enabling Reduce Motion makes it instant. Restore it from the Aqua dock, its desktop icon in other themes, or its labelled entry in Window. **Window → Minimise** (Command-M) and **Zoom / Restore Size** are available in every theme.

### Tiny-screen mode

Enable **Control Panel → Appearance → Tiny-screen mode — 2×**, or **View → Tiny-screen Mode**, to make text, icons, controls, and window chrome twice as large. The setting works across all six themes, applies immediately, and survives relaunch. It is off by default. The native macOS View menu also offers the toggle.

The available desktop stays filled, with half as much logical width and height: a 1280 × 720 content area becomes roughly 640 × 360 before menus and the Aqua dock. Finder offers a **Places** toggle and puts the path on a separate line in narrow windows. Print Monitor collapses filters and stacks build rows; scroll to reach more jobs and details. Control Panel puts display settings first, on one line when they fit, and shows smaller theme cards with an always-visible scrollbar. Every bundled app fits the tiny desktop: crowded toolbars shorten their labels or wrap onto a second row, secondary notes move into help, and long lists scroll inside the window. Activity Monitor switches to a compact summary, and very short windows hide its CPU graph so the process list stays visible. The Aqua dock uses a slimmer shelf.

Custom sheets, startup, and screensavers share the enlargement. Native macOS menus, alerts, and file panels keep their system sizing. Bevelled screen edges and rounded corners remain visible in full screen. Tiny-screen and Purist modes are mutually exclusive: enabling one disables the other. Turning the active mode off returns to standard sizing. Display-mode changes retain running app state and do not overwrite saved window placements.

Physical Wokyis testing is deferred until the device arrives. The 2× setting has been checked on a development Mac; its comfort at normal desk distance on the Wokyis is not yet established.

### Purist mode

**Control Panel → Appearance → Purist mode — 512 × 384** runs the desktop at a fixed 512 × 384 logical resolution. It works with every theme and is also available in **View → Purist Mode**. The native app window shrinks to fit; turning the mode off restores its previous larger frame, including after relaunch. Full screen centres the same small desktop against black. Startup uses a compact layout, and screensavers use the same fixed canvas. Menus use compact headings and scroll when long; keyboard selection keeps the selected row visible. App windows retain their saved geometry and expose scrolling when their minimum content is larger than the available window. The Aqua dock uses the same slimmer shelf as tiny-screen mode and offers overflow navigation. Theme changes and display-mode changes keep application state; deliberate dragging/resizing still saves new geometry. The setting is off by default and survives relaunch.

### Saved layout and startup

Open applications, stacking order, positions, sizes, and minimised/zoomed states are saved automatically and restored after the startup sequence. A deliberately empty desktop stays empty. On a first launch, Activity Monitor opens by default. Layouts adapt to the current display without overwriting the saved geometry until you move or resize a window. Unknown application IDs are ignored, and unreadable or unsupported session data falls back to the initial layout.

At launch, a brief Macintosh boot homage shows a happy Mac, then “Welcome to Macintosh.” with a stepped progress bar and a row of startup icons. It uses the selected theme and lasts about four seconds before opening the desktop. Click **Skip startup** or press Escape to enter immediately. **Control Panel → Playfulness → Macintosh startup** disables it for subsequent launches; the Extra silliness master switch and macOS Reduce Motion also bypass it. An original chime plays when System sounds is enabled. The presentation does not measure system boot or application loading. Desktop windows and their input handlers are created afterward. The sequence runs once per launch and does not replay when changing themes, focusing the app, or reopening an application window.

### Menus

The desktop menu bar uses custom themed dropdowns with checkmarks, disabled commands, and shortcut labels. Click a heading to open it, then move across headings to switch menus. Arrow keys navigate, Return activates the selected command, and Escape or a click outside dismisses the menu. Command shortcuts also work while menus are closed; native folder dialogs retain their normal keyboard behavior.

## Appearance and Aqua dock

Choose Classic, Paper, Midnight, System 7, Platinum, or Aqua in **Control Panel → Appearance**. Themes change Hello Mini, not the system-wide macOS appearance, and keep application state intact.

**Platinum** is a Mac OS 8 homage: bevelled grey windows and buttons, ridged title bars, heavy condensed type, shaded colour icons, and a blue woven desktop. Its title bars carry close, zoom, and collapse boxes. **Window shade** rolls a window up to its title bar: click the collapse box, double-click the title bar, or choose **Window → Collapse Window**. The application keeps running, and its contents return when you expand the window. Shaded windows pause their graphics like covered ones. Shade state survives relaunch and applies only in Platinum.

Classic uses a dotted monochrome desktop; Paper is plain white; Midnight inverts the palette. System 7 adds lavender, coloured icons, and striped grey title bars.

**Control Panel → Appearance → Aqua** selects the early OS X homage: blue wave wallpaper, fine horizontal pinstripes, rounded shadowed windows, glossy red/yellow/green window buttons, blue gel controls, and smooth colourful icons. 

A translucent dock replaces the desktop app column in Aqua, with all applications, running triangles, hover labels, and separate minimised-window tiles after a divider. Click an app to launch, focus, or restore it; click a minimised tile to restore its window. Icons shrink to fit, and crowded docks offer horizontal scrolling and arrows to reach either end. **View → Focus Dock** enables left/right keyboard navigation; Space or Return activates the selected item and Escape leaves the dock. Window zoom, drag, and resize bounds reserve space above the shelf without rewriting saved positions on a theme change. Minimise state survives relaunch, so its tiles return too. Other themes retain the desktop application column. The wallpaper is static and adds no animation loop; existing graphics and playfulness controls continue to work. The app's Dock icon stays the shared Hello Mini identity.

Known visual limitation: a theme thumbnail can partially repaint after a live appearance change. Reopening Control Panel refreshes the previews; desktop styling and application state are unaffected.

## Finder

The Finder browses real folders, with icon and list views, back/up navigation, hidden-file visibility, and a folder chooser. Its last folder, icon/list mode, and hidden-file preference survive relaunches; navigation history starts fresh. Missing or inaccessible restored folders use the normal error view and folder chooser. Double-click a folder to browse it or a file to open it with its default macOS application. Right-click an item to reveal it in macOS Finder. Folder access follows normal macOS permissions; errors appear in the window. The context menu offers seven colour labels, updating the matching named macOS tag and legacy colour while preserving unrelated tags. File contents are unchanged; move and delete operations remain future work.

## Activity Monitor

Activity Monitor shows local CPU, a two-minute history, memory, load averages, uptime, disk space, and processes. Sampling runs every two seconds while open, with pause/resume, name/PID filtering, and CPU or memory sorting. Closing stops sampling; resuming starts a fresh CPU history.

Activity Monitor's system CPU percentage is the difference between kernel CPU tick counters, normalized across all cores. Its first reading needs two samples. Process CPU comes from `ps` and can exceed 100% for multithreaded processes; process memory is RSS, which can include shared pages. These values do not sum to the system totals. Memory shows wired, compressed, and free physical pages separately, not a memory-pressure estimate. No process termination controls are included. Only executable names are read, never command arguments. This monitors the local Mac, not CI workflow or job status.

## Clock and About Mini

Clock shows local and UTC time and a monotonic stopwatch. A running stopwatch continues counting while its window is closed. About Mini shows application and system information.

## Playfulness

Creeping anachronism is part of the design: modern GPU effects should borrow the selected theme's visual language. **Control Panel → Playfulness** has an **Extra silliness** master switch and individual effect switches, independent of the theme. Choices apply immediately and persist across launches. Disabling the master switch preserves each effect's preference.

**Teapot animation** controls automatic rotation. It stops automatic rotation in an already-open Teapot window, retaining manual orbit, shading modes, and the app's own pause/resume choice. Re-enabling it does not open Teapot or undo a manual pause. Reduce Motion still prevents automatic rotation.

The Playfulness pane also lists the future ideas explicitly as planned: fluid **Living dither**, particle-based **Impossible instruments**, folding **Physical windows**, and stippled 3D **Depth behind glass**. These renderers are not implemented yet; each will receive its own working switch when registered.

## Screensavers

**Control Panel → Screensavers** selects Aquarium, Flying Toasters, or Scrapbook Slideshow, previews the selected saver, and sets an idle delay of 1, 2, 5, 10, 15, or 30 minutes. The default is **Never**. Selection and delay survive relaunches. Aquarium's own **Screensaver preview** button previews its fish without changing the saved selection.

**Flying Toasters** supplies original procedural pixel artwork: winged appliances and slices of toast travelling diagonally across a field of theme ink. Metal renders the parade at up to 30 fps with a bounded drawable. **Control Panel → Playfulness → Flying toaster animation** freezes the flight; Aquarium retains its own animation and activity switches. Turning off **Extra silliness** disables both previews and idle activation while preserving preferences. Reduce Motion disables automatic activation and keeps manual previews still.

**Scrapbook Slideshow** shows the pictures on your Scrapbook shelf, newest first, framed with their title and date. It moves to the next picture every seven seconds with a cross-fade, or without one under Reduce Motion. Archived scraps are never shown, and an empty scrapbook shows a note instead.

Automatic activation requires Hello Mini to be active, with its desktop window visible and focused, no native sheet or modal dialog, and no held mouse button or live window resize. Input resets the timer. Time spent inactive, asleep, or across a delayed timer callback does not count toward activation. The saver covers the desktop window's current display; it dismisses on mouse movement, clicking, scrolling, or a key press, and when focus leaves it. The waking event is consumed so it does not also invoke a desktop command. macOS sleep and lock behaviour are unchanged; this is an app presentation, not an installed `.saver` or lock screen.

## Teapot

Launch **Teapot** for a rotating Utah teapot. Choose Dither, Smooth, or Wireframe, pause rotation, orbit with the arrow buttons, or reset the view. Dither uses the selected theme’s ink and paper colours. Reduce Motion stops automatic rotation while keeping manual orbit available. If Metal cannot initialise, the window shows an explanation.

## Aquarium

Open **Aquarium** from the desktop or application menus for nine fish, bubbles, plants, gravel, and stippled underwater light. **Feed fish** drops food and draws the fish toward it; **Pause** freezes the tank without accumulating motion to catch up on later. The Aquarium menu provides the same feeding and pause controls.

**Control Panel → Playfulness → Aquarium animation** and the Extra silliness master switch control automatic motion. Reduce Motion also keeps the tank still. **Reflect system activity** is off by default and persists independently: enable it in Control Panel or the Aquarium menu for CPU-driven plant and bubble currents and extra bubbles from network traffic. The tank displays numerical readings alongside the animation. Sampling runs every two seconds while the tank is open and Hello Mini is active. It reads CPU tick deltas and combined inbound/outbound byte counters for active Ethernet/Wi-Fi (`en*`) interfaces, excluding VPN and loopback traffic. It reads no packet content and sends no telemetry anywhere. Initial readings and counter resets wait for a fresh delta.

**Screensaver preview** uses the shared screensaver host described above. The windowed tank suspends its animation and sampling during the presentation; the saver uses the same fish, simulation clock, and pending food. Print Monitor can feed the fish after newly observed successful builds; see [Build-time lunch](#build-time-lunch).

## Scrapbook

Open **Scrapbook** from its desktop icon or the application menus. **New…** creates a note, command, or web link; **Edit…** changes a scrap's title and contents, or an image's caption. Save commits the edit; Cancel leaves the saved version intact. Commands remain text to copy into your own tools. Web links accept HTTP/HTTPS addresses and open only when you choose **Open Link**.

**Paste as New** (Shift-Command-V) captures the current text, web address, image, or first copied file. **Import…** adds a UTF-8 text file or image through the normal file picker. Clipboard content is read only on that explicit action; there is no background clipboard history, link fetching, or cloud sync. **Copy** (Shift-Command-C) returns the selected text or image to the clipboard. Normal copy/paste continues to work inside the editor.

Search matches every query word across titles, text, image captions, text found in pictures, and scrap kinds, ignoring case and accents. Hello Mini reads text in image scraps with macOS Vision, on this Mac, one picture at a time after it is added; pictures saved before this feature are read when Scrapbook first opens. The shelf shows **reading text…** while it works, and **Text in picture** reveals what was found. Pictures without readable text are not read again. **Archive** removes a scrap from the shelf; **Show Archive → Restore** brings it back. Archiving preserves both text and image files. There is no permanent-delete action in this version.

The library lives in `~/Library/Application Support/HelloMini/Scrapbook/`: a versioned `scrapbook.json` index, a `scrapbook.previous.json` copy of the previous complete index, and UUID-named PNG images. Image imports keep the first frame, apply its orientation, and limit the longest edge to 4096 pixels. These are owned snapshots, so moving or deleting an original file does not break the scrap. Text imports are limited to 1 MB, image inputs to 25 MB, and the text index to 64 MB. Back up the whole directory to retain the images as well as the index.

Saves are atomic. Failed saves retain your draft; an unreadable or newer-format library opens with an error and disables writes instead of replacing your data.

## Desk Calculator, World Clock, and Puzzle

**Desk Calculator** provides five panes: expressions, programmer arithmetic, units, timestamps, and plots. Expressions support parentheses, powers, scientific notation, pi/e, and common functions; angles use radians. General calculations use floating-point numbers. Programmer mode uses signed 64-bit integers with decimal, hexadecimal, and binary inputs, checked arithmetic overflow, bitwise operations, and shifts. Hex/binary inputs represent bit patterns; right shifts preserve the sign. Results can be selected or copied.

Unit conversion covers distance, mass, temperature, and binary byte multiples. Time conversion accepts Unix seconds or an ISO 8601 date with a timezone. Plotting samples x and y from −10 to 10, omitting undefined/out-of-range samples and breaking large jumps; it is a small plotting aid, not a symbolic algebra system. **Unreasonable mathematics** opens a decorative Metal Mandelbrot excursion. Its Control Panel switch disables this spectacle while keeping the calculator available.

**World Clock** extends `MiniClock` with saved time zones, weekday working hours, a −12…+36 hour preview, and Mac uptime. Foundation supplies timezone and daylight-saving rules. The rotating globe is deliberately stylized, not a geographic map or daylight reference. **Control Panel → Playfulness → World Clock globe** stops its rotation; Reduce Motion does too.

**Puzzle** accepts arrow keys to move the empty space, or clicks on adjacent tiles. It is a 15-tile sliding puzzle shuffled through legal moves so every starting board is solvable. Tiles show a picture of Hello Mini's own window, including the puzzle. It never captures other apps or requires Screen Recording permission. **Freeze tiles** and **Refresh picture** control the image; **Live puzzle tiles** in Control Panel controls automatic one-second refreshes. Inactive, closed, or reduced-motion views stop automatic refreshes. Captures skip mouse drags and native live resizing. Native/Metal surfaces can be absent from AppKit's cached picture; the numbered puzzle remains playable.

## Chooser, Disk First Aid, and Wastebasket

**Chooser** browses Bonjour advertisements for SSH, Screen Sharing, HTTP, or HTTPS only after **Browse**. Select a resolved service or type a hostname/IP address, then **Connect** opens the matching macOS handler. It does not scan ports or initiate connections automatically. Discovery stops when the window closes. macOS may request Local Network access; discovery errors stay visible in Chooser.

**Disk First Aid** lists mounted volumes, capacity, free space, format, and write availability. **Inspect** reads the volume's available SMART information using `diskutil info`; unsupported devices say that health is not reported. APFS volumes can share free space, so volume totals should not be summed. This is read-only inspection with no repair controls.

**Wastebasket → Scan caches** reviews the current user's Xcode DerivedData, SwiftPM cache, and Xcode cache. **Add Swift project…** adds only that project's `.build` contents to the review. The app shows names, paths, and estimated allocated sizes, with nothing selected automatically. Review selected paths in the confirmation before moving them to macOS Trash; restore mistakes through macOS Trash. There is no permanent-delete action. Close affected builds/tools first; these are rebuildable caches, but removing active caches can interrupt work.

Cache scans skip symbolic links and mark incomplete size estimates with **+**. Changed or inaccessible items stay in the review with an error. Sizes do not account for APFS sharing.

## Print Monitor

**Print Monitor → Projects…** saves up to 12 GitHub or GitLab projects, including self-hosted servers. Choose a provider, enter an `owner/project` path (GitLab subgroups are supported), and choose **Add**. The **Queue** selector switches between one project and **All projects** without restarting its completion history. An existing single-project configuration migrates automatically, preserving its original Keychain account.

### Self-hosted servers

For GitHub Enterprise Server or GitLab Self-Managed, enable **Self-hosted server** when adding a project and enter its HTTPS website address, such as `https://git.example.com:8443`. Omit the API path: Hello Mini derives `/api/v3` for GitHub Enterprise Server and `/api/v4` for GitLab. Only installations at the website root are supported; subpath installations, HTTP, and certificate-validation bypasses are not supported. Certificates must be trusted by macOS. The server is shown in project and job details. To change it, add the project on the new server and remove the old entry; tokens are never transferred between servers.

### Queues and refresh

**Branch** and **Workflow** narrow the recent builds already loaded. They match exact branch names and GitHub workflow names; selecting a workflow shows GitHub builds only. Choices come from the selected queue, with a saved choice retained even when no recent build matches. Filters persist across relaunches and queue changes; **Clear** restores all loaded builds. They do not search older history, issue extra requests, or change completion tracking and fish feeding. The printer's paper jam follows each project's latest matching build.

The app reads up to 20 recent builds per project. The combined queue labels every build with its provider and project, puts running/queued/waiting builds first, then sorts by creation date, with stable fallback ordering for missing dates. Run identities include the project, so identical numeric IDs from different sources stay separate. Each project shows its own last successful refresh and error; one failed request leaves the other queues working and retains that project's last good readings.

Automatic refresh runs while Hello Mini is running, even with Print Monitor closed or the native app inactive. A full cycle is spaced at 90 seconds per saved project (90 seconds for one, 180 for two, and so on), with no more than three requests in flight. Fresh projects are not re-fetched just because a project was added or the window reopened. **Pause** stops automatic checks; **Refresh all** explicitly refreshes every saved project regardless of the visible queue. Repeated manual refreshes can still hit provider rate limits. Queue selection, projects, and their original path spelling survive relaunches; run snapshots and completion histories last for the app session.

### Tokens

Public projects can work without a token. Each saved project's **Token…** action opens an editor tied to that exact project, with explicit save and forget actions. Use GitHub Actions read access or GitLab `read_api` access. Tokens stay in this Mac's Keychain and are sent only to the configured server's HTTPS API origin, never in URLs or preferences. Removing a project keeps its token; forget it first if you want it removed. A new installation starts with no projects. Unreadable or unsupported saved libraries remain untouched and block edits instead of replacing data. Existing public-service token accounts are preserved; custom server addresses, including non-default ports, have separate token accounts.

### Jobs and failures

**Jobs…** opens an on-demand job sheet for a build. It shows job states, completed durations, GitHub steps and failed-step names, or GitLab stages, reported failure reasons, and allowed failures. **Open job logs** opens the job on its provider; **Build & artifacts** opens the run page. Refresh checks the latest job attempts again, while Load more jobs fetches another page of up to 100 (500 jobs maximum). Failed requests keep previously loaded jobs visible, and closing the sheet cancels its requests. GitLab trigger jobs and child pipelines remain on the provider page. Raw logs and artifacts are not downloaded inside Hello Mini. The printer feeds imaginary paper while builds run and reports a paper jam when any visible project's latest matching build failed; real run states remain visible. **Control Panel → Playfulness → Print Monitor paper** and Reduce Motion stop its animation.

## Build-time lunch

**Control Panel → Playfulness → Feed fish after successful builds** is enabled by default. When Print Monitor receives a successful refresh, newly successful builds cause one food drop per batch and an Aquarium note such as “A build passed. Lunch is served.” Ordinary manual feeding remains available. Aquarium need not be open: it remembers the latest meal until its renderer next runs. Paused/reduced-motion tanks retain the food without forcing motion.

**Control Panel → Playfulness → Fish remember builds** is on by default. Consecutive successful builds grow the fish, and a fifth green build in a row brings a tenth resident. Ten in a row reach full size. A failed build resets the streak and sends the fish sulking along the gravel until the next success. The streak and mood survive relaunch. Turning the switch off pauses the memory and draws the ordinary nine fish.

**Control Panel → Playfulness → Talking Moose** is off by default. When enabled, a pixel moose peeks up from the bottom-left corner to comment out loud on newly passed or failed builds, using macOS speech at the normal system volume. Each remark also appears in a balloon, at most one every 20 seconds. Click the moose to send it away.

The first successful refresh for each project after launch or re-adding it establishes a baseline and does not feed from old history. Later refreshes detect transitions to success and newer successful run IDs, including builds that finish between polls. Repeated refreshes and repeated successes for the same retained run ID do not feed again. Each saved project retains its own tracker of the latest 200 observed IDs during the app session. Switching the visible queue preserves all trackers; removing a project discards its tracker, and relaunching establishes fresh baselines. Successful responses in one refresh cycle produce one combined food drop. Failed requests do not change this history. The host polls while Hello Mini is running, including with Print Monitor closed or the native app inactive. Pause in Print Monitor suspends automatic polling. Relaunch establishes fresh completion baselines.

Turning off the feeding switch or Extra silliness consumes notifications without feeding; re-enabling it does not replay missed meals.

## Desktop accessories and polish in 0.2.0

**Control Panel → Playfulness → System sounds** controls original synthesised startup, jam, feeding, cleanup, and alarm cues. Extra silliness and normal macOS output volume/mute apply. The menu bar printer reports the latest build across every saved project, independent of visible queue filters; hover for refresh errors or pause state. Click it to open Print Monitor. The thermometer reports thermal state rather than degrees. Aqua dock tiles show attention badges, optionally magnify on hover, and bounce twice when an application is newly opened from the dock or a menu. **Control Panel → Playfulness → Dock launch bounce** controls the cue; Reduce Motion, inactive desktops, and screensavers suppress it. Restoring a saved session or activating an already-open app does not bounce.

**Clear jam…** on a failed build opens a retry dialog. GitHub retries failed jobs and their dependents through its [failed-job rerun endpoint](https://docs.github.com/en/rest/actions/workflow-runs#re-run-failed-jobs-from-a-workflow-run); GitLab's [pipeline retry endpoint](https://docs.gitlab.com/api/pipelines/#retry-jobs-in-a-pipeline) retries failed and cancelled jobs. Tokens need Actions write access on GitHub or API scope and pipeline retry permission on GitLab. **Copies** means up to three attempts, defaulting to one. Further copies wait for an observed active attempt to fail; success, cancellation, a missing run, uncertain responses, or a 30-minute wait limit stop the sequence. Closing the dialog stops remaining copies; submitted jobs continue on the provider. Write requests never follow redirects or automatically repeat after an error.

**Edit → Show Clipboard** opens an on-demand text/image snapshot. **File → Capture Desktop to Scrapbook** saves an image of Hello Mini's own desktop without touching the clipboard. Command-Shift-3 works when delivered to Hello Mini; macOS may reserve that shortcut, so the menu command is the reliable alternative. Capture errors appear in Scrapbook or the desktop.

**Special → Empty Wastebasket…** opens the existing cache review; only explicitly selected items move to macOS Trash. **Restart** relaunches Hello Mini, and **Shut Down** quits it. System 7's optional menu blink flashes a chosen command three times. **Help → Show Balloon Help** enables explanations for controls with help text; native tooltips and accessibility hints remain available. Motion effects respect Reduce Motion.

**Key Caps** offers a fixed US keyboard with Shift, a curated symbol/emoji palette, arbitrary Unicode text to copy, and a button for the native macOS character viewer. **Alarm Clock** has timers from 1 minute to 24 hours, 25-minute focus sessions, and 5-minute breaks. Each session starts explicitly. Timers use saved wall-clock deadlines: sleep counts, overdue alarms fire on wake or next launch, and a ringing alarm remains visible until dismissed. The menu bar alarm works with the accessory closed and remains steady when motion is disabled.

**Find File**, also available through Finder's **Find…** button or Command-F, searches indexed file names within your home folder or a chosen folder. It shows up to 200 results with explicit Open/Reveal actions. Spotlight indexing and macOS access permissions determine which files appear; this is not a full disk traversal. **Control Panel → Appearance → Desktop Pattern** supplies a saved 8 × 8 pixel editor with immediate desktop preview, Clear, and Reset to theme.

Genie minimisation and other physical keyboard layouts remain on the roadmap.
