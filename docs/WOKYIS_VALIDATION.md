# Wokyis and lifecycle validation

## 18 October 2026 — Hello Mini 0.9.0

Release source: `c1be334bc6dbc373e9a8baa8bad1b06729f75ad0`, build 9, installed by Homebrew at `/Applications/Hello Mini.app` on the M4 Mini.

Before connecting, `system_profiler SPDisplaysDataType` reported the physical Wokyis as the main, online display at 1280 × 720, 60 Hz. The running application was still the manually installed 0.5.0 copy in `~/Applications`; Homebrew had correctly installed 0.9.0 separately. The older process was quit through its own menu. The Homebrew copy was opened through Finder, passed the normal macOS first-launch prompt, and its running executable path was verified.

The initial screen-sharing session subsequently reported only a **Screen Sharing Virtual Display**, 3840 × 2160 pixels / 1920 × 1080 logical points. Results from that session establish behaviour on the Mini with a virtual display, not physical Wokyis legibility.

The saved Screen Sharing connection used High Performance mode. Earlier attempts to change it and reconnect still resumed a virtual display. A keyboard-free recovery was subsequently verified over SSH:

1. Close the viewer before reconnecting so it cannot immediately resume the old session.
2. Identify the logged-in user's `ScreensharingAgent` process with `ps`, and send `SIGTERM` to that specific process. Do not terminate `WindowServer`, `loginwindow`, or unrelated processes. `launchctl kill` refused permission on this host, but a normal signal to the user-owned agent succeeded without sudo.
3. Confirm `system_profiler SPDisplaysDataType` reports the Wokyis again.
4. In Screen Sharing's saved connection, choose Edit, select **Standard**, and use **Connect** directly. The saved entry was found to show High Performance again, so verify the selection rather than assuming an earlier change persisted.
5. After reconnecting, verify the host display identity again. This connection retained the Wokyis at **1280 × 720, 60 Hz**, with no virtual display reported and no “Locked” label in the viewer.

Apple's physical-Escape method is therefore not required for this tested recovery path. No administrator password, logout, reboot, or CI-service restart was needed.

### Completed on the Wokyis console after recovery

- The same Homebrew 0.9.0 process remained running across the virtual-display teardown and physical-display restoration. Its full-screen desktop and Print Monitor reflowed to the smaller physical display; the menu, window chrome, filters, project control and refresh controls were visible.
- The old Dock item was confirmed to launch the manual 0.5.0 copy. That copy was quit through its menu, and the existing Homebrew process was activated. The final process check showed only `/Applications/Hello Mini.app/Contents/MacOS/HelloMini` running.
- Standard and Purist were exercised on the physical console. Purist centred its 512 × 384 desktop with black margins; Print Monitor menus, filters, scrolling and project controls remained reachable. Teapot continued rendering and rotating in both modes.
- Changed the actual Wokyis resolution from 1280 × 720 to 1920 × 1080 at 60 Hz and back, verifying each mode over SSH. Full-screen content reflowed and Metal rendering continued. Repeated the round trip with the development fixes below and verified that leaving full screen kept all native-window edges on screen.
- Display sleep passed: `pmset displaysleepnow` at **21:23:20 CEST**, display-on at **21:23:32** after remote input, confirmed by `pmset -g log`. The Wokyis remained online at 1280 × 720; input and Teapot animation recovered.
- A software system-sleep request at **21:32:50** entered **DarkWake**, with TCP keep-alive active. Logs recorded **DarkWake to FullWake from Deep Idle** due to HID activity at **21:33:38**, followed by display-on. Graphics, input, menu clock, Activity Monitor and subsequent Print Monitor refresh remained functional. This is a DarkWake recovery check, **not a full system-sleep pass**. Wake packets were sent, but this does not establish successful wake-on-LAN because the CPU did not fully sleep.

### Issues found and fixed after 0.9.0

These source changes are not part of the published 0.9.0 binary. An ad-hoc development bundle was tested separately in `/private/tmp/hellomini-wokyis-check`; the Homebrew installation was not replaced.

- **Projects sheet clipped horizontally in Purist:** its fixed 550-point content width exceeded the 512-point desktop. The sheet and content now use the available logical width. On the Wokyis, Add, Token and Remove fit fully; vertical scrolling exposed a complete, working Done button. Regression geometry checks cover Purist and 2× logical sizes.
- **Native window extended off screen after resolution changes:** leaving full screen could restore a frame from the larger display. Screen-parameter changes and full-screen exit now clamp the entire window to the current visible screen; restoring the pre-Purist frame uses the same constraint. The repeated physical resolution round trip passed. Tests cover oversized frames and screens with negative origins.
- `make check` passed with these fixes, including layout, desktop lifecycle and release-mode Print Monitor checks. The Living dither lifecycle test now explicitly runs on the main actor, removing its isolation warning.

### Completed in the virtual-display session

- Upgrade from the existing saved 0.5 desktop retained configured CI projects and restored windows. Public GitHub requests displayed access/rate-limit errors; this is not evidence of a display failure or successful live-provider validation.
- Entered full screen through the themed View menu. The desktop and controls reflowed to the available display area.
- Control Panel theme cards responded at their drawn positions at 2×; Paper, Midnight and System 7 were selected.
- Switched from 2× to Purist in full screen. The 512 × 384 logical desktop was centred with black surrounding space and retained a reachable Control Panel and display-mode switches.

### Test environment constraints

The Mini runs an active BombCAD CI job and a MotionStudies Node recorder with `caffeinate -is` assertions; screen sharing itself also holds a prevent-system-sleep assertion. No CI process was killed or keep-awake service disabled for these checks. A full sleep/wake result must be backed by power-management log evidence, rather than inferred from a black screen or reconnection.

A full system-sleep cycle remains unverified: the software-sleep attempt reached DarkWake while those assertions were active. The user has confirmed a physical power-button wake fallback; that solves recovery availability but does not remove the active workloads or their assertions. Complete a full cycle during an idle maintenance window and require actual system-sleep/wake log evidence. Cable hot-plug, a comprehensive bundled-app/keyboard audit, comparison with 1.5×, and a multi-hour soak also remain separate follow-ups.

Physical panel reading distance, ambient light, viewing angle and subjective legibility require a person at the Wokyis. A remotely enlarged screenshot cannot establish these.

## Repeatable checks

1. Verify both the installed version and the actual running executable; a manual copy in `~/Applications` may otherwise continue running after a Homebrew upgrade.
2. Record `system_profiler SPDisplaysDataType` before and after connection. Confirm Wokyis remains online; do not count a virtual display as the physical panel.
3. In Standard, 2× and Purist, exercise full-screen entry/exit, theme selection, menus, scrolling, sheets and graphics. Check that open documents and saved placements survive temporary constraints.
4. Change an available macOS display resolution and restore it. Record both modes and check recovery of window chrome, controls and Metal rendering. Cable removal/reconnection is a separate physical test.
5. Exercise display sleep and full system sleep separately. Record actual sleep/wake events and verify graphics movement, input, clocks, refresh and saved state after wake. Arrange a reliable wake path before sleeping a remote CI host.
6. Restore the starting theme, mode and window arrangement; record duration and number of cycles. A short functional check is not a multi-hour soak.
