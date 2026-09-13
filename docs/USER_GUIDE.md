# Using Hello Mini

This guide describes the published **0.1.0** app. Proposed accessories and later work are tracked separately in the [roadmap](../ROADMAP.md).

[Install or update](INSTALL.md) · [Desktop](#desktop-and-keyboard-controls) · [Appearance](#appearance-and-aqua-dock) · [Print Monitor](#print-monitor) · [Scrapbook](#scrapbook) · [Screensavers](#screensavers)

Launch apps from desktop icons, the Aqua dock, the Macintosh menu, or Window. **Option-Command-M** opens the desktop launcher: use arrows or an application's initial, then Return. Escape dismisses it. Desktop icons scroll when the application list is taller than the display. Control Panel changes apply immediately and are saved.

## Desktop and keyboard controls

The desktop opens at 1280 × 720. Use View → Enter / Exit Full Screen (or Control-Command-F) for a dedicated display. Drag the striped title bars to move windows, or the bottom-right corner grips to resize them. Grips also expose accessibility increment/decrement actions. Each app supplies a minimum size; windows stay inside the available desktop. 

The Window menu reopens closed windows and **Reset Window Layout** restores their default positions and sizes. 

Aqua adds working red **Close**, yellow **Minimise**, and green **Zoom** controls, with hover symbols and inactive grey states. Zoom fills the available desktop and toggles back to the previous geometry; dragging or resizing a zoomed window establishes a new normal size. Minimise keeps the application and its view state alive, hides the window, and gives focus to the next visible window. Restore it from the Aqua dock, its desktop icon in other themes, or its labelled entry in Window. **Window → Minimise** (Command-M) and **Zoom / Restore Size** are available in every theme.

### Purist mode

**Control Panel → Appearance → Purist mode — 512 × 384** runs the desktop at a fixed 512 × 384 logical resolution. It works with every theme and is also available in **View → Purist Mode**. The native app window shrinks to fit; turning the mode off restores its previous larger frame, including after relaunch. Full screen centres the same small desktop against black. Startup uses a compact layout, and screensavers use the same fixed canvas. Menus use compact headings and scroll when long; keyboard selection keeps the selected row visible. App windows retain their saved geometry and expose scrolling when their minimum content is larger than the available window. The Aqua dock still reserves its space and offers overflow navigation. Theme changes and display-mode changes keep application state; deliberate dragging/resizing still saves new geometry. The setting is off by default and survives relaunch.

### Saved layout and startup

Open applications, stacking order, positions, sizes, and minimised/zoomed states are saved automatically and restored after the startup sequence. A deliberately empty desktop stays empty. On a first launch, Activity Monitor opens by default. Layouts adapt to the current display without overwriting the saved geometry until you move or resize a window. Unknown application IDs are ignored, and unreadable or unsupported session data falls back to the initial layout.

At launch, a brief Macintosh boot homage shows a happy Mac, then “Welcome to Macintosh.” with a stepped progress bar and a row of startup icons. It uses the selected theme and lasts about four seconds before opening the desktop. Click **Skip startup** or press Escape to enter immediately. **Control Panel → Playfulness → Macintosh startup** disables it for subsequent launches; the Extra silliness master switch and macOS Reduce Motion also bypass it. This is a silent presentation, not a measure of system boot or application loading. Desktop windows and their input handlers are created afterward. The sequence runs once per launch and does not replay when changing themes, focusing the app, or reopening an application window.

### Menus

The desktop menu bar uses custom themed dropdowns with checkmarks, disabled commands, and shortcut labels. Click a heading to open it, then move across headings to switch menus. Arrow keys navigate, Return activates the selected command, and Escape or a click outside dismisses the menu. Command shortcuts also work while menus are closed; native folder dialogs retain their normal keyboard behavior.

## Appearance and Aqua dock

Choose Classic, Paper, Midnight, System 7, or Aqua in **Control Panel → Appearance**. Themes change Hello Mini, not the system-wide macOS appearance, and keep application state intact.

Classic uses a dotted monochrome desktop; Paper is plain white; Midnight inverts the palette. System 7 adds lavender, coloured icons, and striped grey title bars.

**Control Panel → Appearance → Aqua** selects the early OS X homage: blue wave wallpaper, fine horizontal pinstripes, rounded shadowed windows, glossy red/yellow/green window buttons, blue gel controls, and smooth colourful icons. 

A translucent dock replaces the desktop app column in Aqua, with all applications, running triangles, hover labels, and separate minimised-window tiles after a divider. Click an app to launch, focus, or restore it; click a minimised tile to restore its window. Icons shrink to fit, and crowded docks offer horizontal scrolling and arrows to reach either end. **View → Focus Dock** enables left/right keyboard navigation; Space or Return activates the selected item and Escape leaves the dock. Window zoom, drag, and resize bounds reserve space above the shelf without rewriting saved positions on a theme change. Minimise state survives relaunch, so its tiles return too. Other themes retain the desktop application column. The wallpaper is static and adds no animation loop; existing graphics and playfulness controls continue to work. The app's Dock icon stays the shared Hello Mini identity.

Known visual limitation: a theme thumbnail can partially repaint after a live appearance change. Reopening Control Panel refreshes the previews; desktop styling and application state are unaffected.

## Finder

The Finder browses real folders, with icon and list views, back/up navigation, hidden-file visibility, and a folder chooser. Its last folder, icon/list mode, and hidden-file preference survive relaunches; navigation history starts fresh. Missing or inaccessible restored folders use the normal error view and folder chooser. Double-click a folder to browse it or a file to open it with its default macOS application. Right-click an item to reveal it in macOS Finder. Folder access follows normal macOS permissions; errors appear in the window. This first version does not modify, move, or delete files.

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

**Control Panel → Screensavers** selects Aquarium or Flying Toasters, previews the selected saver, and sets an idle delay of 1, 2, 5, 10, 15, or 30 minutes. The default is **Never**. Selection and delay survive relaunches. Aquarium's own **Screensaver preview** button previews its fish without changing the saved selection.

**Flying Toasters** supplies original procedural pixel artwork: winged appliances and slices of toast travelling diagonally across a field of theme ink. Metal renders the parade at up to 30 fps with a bounded drawable. **Control Panel → Playfulness → Flying toaster animation** freezes the flight; Aquarium retains its own animation and activity switches. Turning off **Extra silliness** disables both previews and idle activation while preserving preferences. Reduce Motion disables automatic activation and keeps manual previews still.

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

Search matches every query word across titles, text, image captions, and scrap kinds, ignoring case and accents. It does not perform OCR on image pixels. **Archive** removes a scrap from the shelf; **Show Archive → Restore** brings it back. Archiving preserves both text and image files. There is no permanent-delete action in this version.

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

Automatic refresh runs while Hello Mini is active and Print Monitor is open. A full cycle is spaced at 90 seconds per saved project (90 seconds for one, 180 for two, and so on), with no more than three requests in flight. Fresh projects are not re-fetched just because a project was added or the window reopened. **Pause** stops automatic checks; **Refresh all** explicitly refreshes every saved project regardless of the visible queue. Repeated manual refreshes can still hit provider rate limits. Queue selection, projects, and their original path spelling survive relaunches; run snapshots and completion histories last for the app session.

### Tokens

Public projects can work without a token. Each saved project's **Token…** action opens an editor tied to that exact project, with explicit save and forget actions. Use GitHub Actions read access or GitLab `read_api` access. Tokens stay in this Mac's Keychain and are sent only to the configured server's HTTPS API origin, never in URLs or preferences. Removing a project keeps its token; forget it first if you want it removed. A new installation starts with no projects. Unreadable or unsupported saved libraries remain untouched and block edits instead of replacing data. Existing public-service token accounts are preserved; custom server addresses, including non-default ports, have separate token accounts.

### Jobs and failures

**Jobs…** opens an on-demand job sheet for a build. It shows job states, completed durations, GitHub steps and failed-step names, or GitLab stages, reported failure reasons, and allowed failures. **Open job logs** opens the job on its provider; **Build & artifacts** opens the run page. Refresh checks the latest job attempts again, while Load more jobs fetches another page of up to 100 (500 jobs maximum). Failed requests keep previously loaded jobs visible, and closing the sheet cancels its requests. GitLab trigger jobs and child pipelines remain on the provider page. Raw logs and artifacts are not downloaded inside Hello Mini. The printer feeds imaginary paper while builds run and reports a paper jam when any visible project's latest matching build failed; real run states remain visible. **Control Panel → Playfulness → Print Monitor paper** and Reduce Motion stop its animation.

## Build-time lunch

**Control Panel → Playfulness → Feed fish after successful builds** is enabled by default. When Print Monitor receives a successful refresh, newly successful builds cause one food drop per batch and an Aquarium note such as “A build passed. Lunch is served.” Ordinary manual feeding remains available. Aquarium need not be open: it remembers the latest meal until its renderer next runs. Paused/reduced-motion tanks retain the food without forcing motion.

The first successful refresh for each project after launch or re-adding it establishes a baseline and does not feed from old history. Later refreshes detect transitions to success and newer successful run IDs, including builds that finish between polls. Repeated refreshes and repeated successes for the same retained run ID do not feed again. Each saved project retains its own tracker of the latest 200 observed IDs during the app session. Switching the visible queue preserves all trackers; removing a project discards its tracker, and relaunching establishes fresh baselines. Successful responses in one refresh cycle produce one combined food drop. Failed requests do not change this history. Print Monitor must be open and checking (or manually refreshed); this adds no background CI watcher.

Turning off the feeding switch or Extra silliness consumes notifications without feeding; re-enabling it does not replay missed meals.
