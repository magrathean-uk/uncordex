# GUI implementation handoff

Checkout: `/Users/bolyki/dev/source/uncordex`

Build artifact: `/Users/bolyki/dev/build/uncordex/gui/Uncordex.app`

## Changed files

- `app/Info.plist`
- `app/Sources/AppDelegate.swift`
- `app/Sources/AppModel.swift`
- `app/Sources/FixtureAdapter.swift`
- `app/Sources/Main.swift`
- `app/Sources/Models.swift`
- `app/Sources/ProcessRunner.swift`
- `app/Sources/ServiceAdapter.swift`
- `app/Tests/AppTests.swift`
- `app/build.sh`
- `app/test.sh`
- `docs/app.md`
- `docs/plans/gui-handoff.md`
- `icon/Uncordex.icns` (byte-for-byte copy from main commit `7cac746586c4ed4003f171dca6a250a104e02a72`; parent already owns this commit)
- `install.sh`
- `watch-power`
- `tests/run.sh`

The pre-existing untracked plans `docs/plans/2026-09-09-gui.md` and `docs/plans/2026-09-09-pkg.md` were preserved, not authored by this task.

## Reviewed bundle layout

```text
Uncordex.app/Contents/
├── Info.plist
├── MacOS/Uncordex
└── Resources/
    ├── Uncordex.icns
    └── Service/
        ├── LICENSE
        ├── THIRD_PARTY_NOTICES.md
        ├── VERSION
        ├── install.sh
        ├── uninstall.sh
        ├── watch-power
        └── lib/source.sh
```

The app binary is universal arm64/x86_64, the service scripts retain executable permissions, the identifier is `uk.magrathean.uncordex`, `CFBundleIconFile` is `Uncordex.icns`, and the minimum deployment target is macOS 13.0. The local artifact is ad-hoc signed.

## Interface and safety review

Swift reads installer-owned shell configuration only through `install.sh --gui-status-plist`; it does not implement shell parsing. Cached state comes from `watch-power --status-plist`, whose `state_valid` flag rejects unusable persisted state. Current and cached readings are separately labeled.

All subprocess paths and arguments are distinct values. Commands run off the main thread. A fixed wrapper places each command in a dedicated process group; one deadline covers the command and concurrent locked stdout/stderr drainage, and timeout/post-exit cleanup terminates pipe-holding descendants. The adapter rejects overlapping mutations. The demo adapter is in-memory and cannot reach service or Bluetooth boundaries.

Preview is dry-run only. Preview and Apply enforce `--no-install-dependencies` at execution time. Empty setup has no default rule and cannot silently broaden to any power. Apply is the sole setup action. Running, loaded-not-running, stopped, and not-installed LaunchAgent states are distinct; loaded failures expose Restart and Stop recovery. Stop retains the plist and all service data. Launch, refresh, window close, and quit perform no service or Bluetooth mutations.

The window now constrains its content inside explicit 24-point margins. Status and setup columns have bounded label widths, value labels wrap, pop-ups truncate, and long errors wrap. Default, 620×700 minimum, empty, long-content, light, and Dark Aqua fixture renders were inspected.

## Evidence

- Native adapter/model/process tests: 20 passed, 0 failed at the default root; 20 passed, 0 failed with an explicit nested `UNCORDEX_BUILD_ROOT` override.
- Repository simulated suite: 113 passed, 0 failed.
- Bash syntax: passed for repository scripts plus `app/build.sh` and `app/test.sh`.
- ShellCheck: passed with no findings for repository scripts plus both app scripts.
- Universal binary: arm64 and x86_64 slices confirmed by `lipo`.
- Deployment metadata: `LC_BUILD_VERSION minos 13.0` confirmed independently for both slices.
- Bundle metadata: identifier `uk.magrathean.uncordex`, minimum system version 13.0, version 1.0.0.
- Code signature: strict verification passed; signature is ad hoc.
- Resource layout and executable permissions: inspected and matched the approved contract. Source and bundled icon SHA-256 both equal `e1658d9a66c6dc368b9fc81504d93be740194112546b480c26f799b13f7ac6a7`.
- Fixture visuals: `window.png`, `window-dark.png`, `window-min-long.png`, `window-min-long-dark.png`, and `window-empty.png` under `/Users/test/dev/build/uncordex/gui/visual/`; inspected for default/minimum sizing, long wrapping, stopped retry wording, explicit empty selection, and light/dark appearance.
- Physical hardware and macOS 13 runtime acceptance: not performed.

## Limitations

- `blueutil` remains an external dependency and is never installed by the app.
- Paired-device discovery can include non-speaker Bluetooth devices because `blueutil` does not reliably expose an audio-device class in its JSON output; selection remains explicit.
- No menu-bar companion, direct Bluetooth action, automatic pairing, radio control, or audio-output switching is included.
- Deployment metadata is not evidence of execution on macOS 13; that requires a separate host acceptance run.

Stop here for coordinator review. No commit, installation, publishing, packaging, tag, or release was performed.


## 2026-09-09 native UI revision

The original single-form window described above is superseded by Overview, Speaker & Rule, and Diagnostics in a native AppKit sidebar. The app delegate, window controller, and layout helpers now live in separate files. Setup actions stay visible while content scrolls; Command-1/2/3 and Command-R provide navigation and refresh. Draft setup choices survive refresh and discovery. Save & Start retains the original canonical installer behavior.

Current local build: `/Users/bolyki/dev/build/uncordex/gui/Uncordex.app`.
Current visual evidence: `/Users/bolyki/dev/build/uncordex/gui/visual/` (before, overview, setup-final, empty, diagnostics-dark).

Verification in this checkout: 113 simulated service tests and 20 app tests passed; Bash syntax and ShellCheck passed. The universal app built and strict ad-hoc signature verification passed. Fixture UI checks exercised navigation, discovery, draft preservation across refresh, preview, and stopped-service state. Light, dark, minimum-size, empty, and long-content fixture renders were inspected. Hardware acceptance remains outstanding. No commit, push, installation, or release was performed.

Design references: Apple Human Interface Guidelines for [sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars) and [toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars). The implementation uses AppKit controls and semantic appearance values while retaining the macOS 13 deployment target.
