# Native app development

The AppKit app controls the same per-user watcher as the source installer. It targets macOS 13.0. The build compiles arm64 and x86_64 slices, combines them, and signs the local bundle ad hoc. Runtime compatibility needs checks on the intended hosts.

For user setup, see [Installation](installation.md). For developer checks, see [Development](development.md).

## Bundle

```bash
bash app/build.sh
```

The default result is `$build_root/uncordex/gui/Uncordex.app`, where `build_root` is the development build root described in [Development](development.md#app-and-package-output). `UNCORDEX_BUILD_ROOT` must remain under it. Bundle identifier `uk.magrathean.uncordex` and minimum OS version come from `app/Info.plist`; the version is read from `VERSION`.

`Contents/Resources/Service` contains the installer, uninstaller, watcher, `lib/source.sh`, version, license, and third-party notices. `icon/Uncordex.icns` supplies the app icon, with `icon/appicon-paper-cut.png` used for repository presentation. The external `blueutil` helper is not bundled.

## Service interface

`ServiceAdapter.swift` invokes fixed executable paths with argument arrays. Setup values are not interpolated into shell source. `ProcessRunner.swift` drains both output streams concurrently and supervises command groups with deadlines. The adapter rejects overlapping mutations.

| Operation | Interface |
| --- | --- |
| Current setup and dependency readings | `install.sh --gui-status-plist`, schema 1 |
| Cached watcher observations | `watch-power --status-plist`, schema 1 |
| Source discovery | `install.sh --discover` |
| Preview | Installer with `--no-install-dependencies --dry-run` |
| Save & Start | Installer with `--no-install-dependencies` |
| Start, Stop, Restart | Canonical per-user LaunchAgent through `launchctl` |

Status reads do not change setup or service state. Cached observations are marked invalid when their schema, boot, or rule binding cannot be trusted. The app keeps them distinct from current readings. Missing `blueutil` produces installation guidance rather than an automatic dependency install.

Overview, Speaker & Rule, and Diagnostics separate status, explicit setup, and diagnostics. Empty setup requires the user to choose a reconnection rule. Refresh and discovery preserve draft choices. Failed discovery keeps the prior complete lists. Closing or quitting during a pending operation waits for its completion or timeout; quitting leaves the LaunchAgent running.

## Fixture inspection

After building, capture a fixture window without using the real service:

```bash
"$build_root/uncordex/gui/Uncordex.app/Contents/MacOS/Uncordex" \
  --demo --screenshot "$build_root/uncordex/gui/visual/window.png"
```

With `--demo`, use `--page 0`, `--page 1`, or `--page 2` for the three destinations. Add `--dark`, `--minimum-size`, `--long-content`, or `--empty-setup` to inspect appearance, wrapping, errors, and empty selection. The fixture adapter does not invoke service scripts, `blueutil`, `launchctl`, or hardware.

Run `bash app/test.sh` for model, service-adapter, process, and AppKit window tests. Fixture screenshots and tests do not establish live hardware behavior; report that separately.
