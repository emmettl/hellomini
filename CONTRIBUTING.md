# Contributing

Hello Mini welcomes useful little apps and carefully judged nonsense. Read the [roadmap](ROADMAP.md) and [architecture](README.md#applications-and-architecture) before starting a large change.

Use macOS 26 with Xcode 26.6 / Swift 6.3. Run `make format` and `make check`, then try the app at 1280 × 720 and at the affected window's minimum size. Describe what changes and how you verified it in the pull request. Include screenshots when appearance changes, using demonstration content.

Application modules depend on `MiniCore` and shared `MiniUI` controls. The desktop owns launching, geometry, focus, and menus. Keep app-to-app connections injected by the host. New effects belong in Control Panel, use the current theme, honor Reduce Motion, and pause when hidden or closed. Keep real status understandable when the spectacle is disabled.

Tests should cover behaviour and failure boundaries, especially persisted data, file operations, provider responses, and graphics. Metal rendering tests are required on physical Macs; hosted CI may skip them only when no Metal device exists. Use explicit user actions for imports and connections.

Keep signing credentials and local app data out of the repository. Preserve third-party notices for imported assets. Contributions to this repository are made under its [MIT license](LICENSE); no separate contributor agreement is required.
