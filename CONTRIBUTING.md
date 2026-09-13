# Contributing

Hello Mini welcomes useful little apps and carefully judged nonsense. Read the [roadmap](ROADMAP.md) and [architecture guide](docs/ARCHITECTURE.md) before starting a large change.

Use macOS 26 with Xcode 26.6 / Swift 6.3. Run `make format` and `make check`, then try the app at 1280 × 720, at the affected window's minimum size, and in 512 × 384 Purist mode. For shared controls, check all five themes, keyboard navigation, and Reduce Motion. Describe what changes and how you verified it in the pull request. Include screenshots when appearance changes, using demonstration content.

Application modules depend on `MiniCore` and shared `MiniUI` controls. The desktop owns launching, geometry, focus, and menus. Keep app-to-app connections injected by the host. New effects belong in Control Panel, use the current theme, honor Reduce Motion, and pause when hidden or closed. Keep real status understandable when the spectacle is disabled.

Tests should cover behaviour and failure boundaries, especially persisted data, file operations, provider responses, and graphics. Metal rendering tests are required on physical Macs; hosted CI may skip them only when no Metal device exists. Use explicit user actions for imports and connections.

For documentation-only changes, check relative links, heading anchors, commands, and release status; a full Swift rebuild is unnecessary. Keep the README brief, put application instructions in the [user guide](docs/USER_GUIDE.md), and record proposals in the roadmap rather than describing them as shipped. Website files and deployment settings are documented in [website/README.md](website/README.md).

Keep signing credentials and local app data out of the repository. Preserve third-party notices for imported assets. Contributions to this repository are made under its [MIT license](LICENSE); no separate contributor agreement is required.
