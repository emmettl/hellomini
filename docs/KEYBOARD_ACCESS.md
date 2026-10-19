# Keyboard and accessibility coverage

19 October 2026. This matrix records source review of the accessory controls and targeted live checks in [0.15 validation](0.15_VALIDATION.md). It is not a complete spoken VoiceOver certification. Native macOS keyboard navigation settings affect Tab access to buttons; use the themed menus and their displayed shortcuts where available.

The desktop isolates inactive accessories. Launch or activate an accessory through its launcher/Window menu before using its controls. Aqua's View → Focus Dock supports arrows and Return/Space. Escape dismisses menus and cancellable sheets. Focus after a sheet returns to a stable control in the presenting view; it need not return to the exact row that opened it.

| Accessory | Keyboard route reviewed | Pointer or further coverage |
| --- | --- | --- |
| Finder | Find toolbar, focused entries with Return/Space, operation menus, named destination input; sheet dismissal restores selection/Find | Dragging/resizing windows uses a pointer |
| Find File | Query field, search action and result buttons | Spotlight permissions/results depend on host |
| Print Monitor | Queue/filter pickers, Projects, History, Jobs, Artifacts and reviewed retry controls; child sheets return to Projects, history branch or project path | Live provider actions require a configured project; GitLab unavailable |
| Scrapbook | Search, filters, item buttons, selection/filing menus, editors and archive review; dismissal returns to search | Images/OCR require their own nonvisual content review |
| MiniPaint | Tool and transform menu shortcuts, Undo/Redo, import/export controls; Escape cancels gesture; dismissal returns to canvas | Drawing and creating/moving geometric selections require a pointer |
| Desk Calculator | Text inputs, Calculate/Return, pane pickers, history buttons and copy/send actions | Plot and Glass graphics need a separate nonvisual audit |
| Chooser | Destination fields, saved-service picker, Save/Connect/Browse buttons | Discovery/network availability depends on host |
| Network | Host/port inputs, Call/cancel controls and result text | Live network evidence is separate |
| Communications | View picker, station setup inputs, connect/receive controls; setup dismissal returns to Setup | Visual charts are not a spoken equivalent of all telemetry |
| Activity Monitor | Tabs, filter/input controls and process actions exposed as controls | Graph interpretation needs spoken review |
| Disk First Aid | Volume picker, scan/cancel controls, report text | Disk permissions depend on host |
| Wastebasket | Reviewed scan/cleanup controls and confirmation | Deletion is explicit; do not use real cleanup as a keyboard test |
| Clock | Display/options controls | Clock graphics need spoken review |
| Alarm Clock | Timer inputs/presets and start/stop/dismiss buttons | Audible delivery needs an attended check |
| World Clock | Working-hour pickers, preview slider, Add search and time-zone buttons; Escape and dismissal restore Add | Globe is decorative |
| Key Caps | Shift/symbol toggles, copy buttons, Unicode field/Return and character viewer | Live highlights show US physical positions only; no global capture |
| Puzzle | Focusable board with arrow movement and tile buttons, shuffle/freeze controls | Live desktop picture is visual |
| Aquarium / Teapot | Their control buttons/pickers | Scenes are visual; no equivalent scene exploration claim |
| Control Panel | Themed controls, pickers and text fields across settings | Pattern editing and some visual previews need pointer/nonvisual follow-up |
| Clipboard | Refresh button and selectable text | Image snapshot needs a nonvisual description |
| About Mini | Standard controls and links | No special keyboard interaction |
| Screensavers / Talking Moose | Host settings and dismissal controls | Scene content and spoken Moose need an attended audio pass |

## Recovery policy

Only absent documents become empty documents. Unreadable/newer Paint and Scrapbook files remain intact; failed Paint saves retain edits in memory for PNG export. Scrapbook retains its previous index and the original version-one index when migrating. Desktop reset first preserves the original preference value, including unexpected non-data types; recovery records can be exported. Presets preserve unreadable preferences, allow retry after external repair and retain the previous compatible document at `desktop.presets.v1.previous` before a successful replacement. These are local recovery copies, not a substitute for an external backup. Simultaneous edits by multiple running copies are not a supported merge workflow.
