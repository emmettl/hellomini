# Validation records

Current implementation checks and release evidence are recorded in [0.13 validation](0.13_VALIDATION.md). Its automated and development-Mac results do not imply that the same binary repeated every physical hardware test.

## Open coverage

- Spoken end-to-end VoiceOver and the complete accessory keyboard/graphics workflow matrix.
- Actual full-system sleep/wake during an idle Mini maintenance window; display sleep and DarkWake are distinct observations.
- Attended physical cable hot-plug and a multi-hour Wokyis soak.
- Live GitLab/self-hosted and broader provider retry coverage with suitable endpoints and accounts.

The physical reading comparison supports 2× over 1.5× for the tested Wokyis setup. Keep screenshots, virtual-display checks and physical-panel observations distinct.

## Dated evidence

| Record | Coverage |
| --- | --- |
| [0.13](0.13_VALIDATION.md) | Batch filing/recovery, Finder Redo, event-driven focus, migration and compact-layout checks; signed release and tap evidence. |
| [0.12](0.12_VALIDATION.md) | Collections, Calculator history/handoff, Depth behind glass and migration evidence. |
| [0.11](0.11_VALIDATION.md) | Keyboard/AX isolation, Finder Undo, Physical windows and Mini display sleep. |
| [0.10](0.10_VALIDATION.md) | Chooser, display polish and the physical 1.5×/2× reading comparison. |
| [Wokyis hardware](WOKYIS_VALIDATION.md) | Display identity, console/virtual-session distinctions, resolution changes and display-sleep/DarkWake observations. |

Older release evidence is retained in the [changelog](../CHANGELOG.md) and [GitHub release notes](https://github.com/emmettl/hellomini/releases). These records describe their dated tests; statements about the then-latest release are historical.

When publishing, add the new dated record and update this index. Keep current operating instructions in the user/developer guides, rather than appending release summaries to them or the README.
