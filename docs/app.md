# Uncordex macOS app

`Uncordex.app` is a native AppKit controller for the existing per-user watcher. It targets macOS 13.0, contains universal arm64 and x86_64 executable slices, and keeps `blueutil` as an external Homebrew dependency.

## Build

The build script defaults every product, cache, temporary file, and log to `$HOME/dev/build/uncordex/gui/`:

```bash
app/build.sh
```

Use a separate output below `$HOME/dev/build` with:

```bash
UNCORDEX_BUILD_ROOT="$HOME/dev/build/uncordex/gui-review" app/build.sh
UNCORDEX_BUILD_ROOT="$HOME/dev/build/uncordex/gui-review" app/test.sh
```

Paths outside `$HOME/dev/build`, dot path components, and resolved escapes through the selected root are rejected. The default result is `$HOME/dev/build/uncordex/gui/Uncordex.app`. `Contents/Resources/Uncordex.icns` is the approved app icon. `Contents/Resources/Service/` contains `install.sh`, `uninstall.sh`, `watch-power`, `lib/source.sh`, `VERSION`, `LICENSE`, and `THIRD_PARTY_NOTICES.md` with executable modes preserved for scripts.

The bundle identifier is `uk.magrathean.uncordex`, the minimum system version is 13.0, and the version comes from the repository `VERSION` file. Local builds are ad-hoc signed.

## Test

```bash
app/test.sh
TMPDIR="$HOME/dev/build/uncordex/gui/tmp" bash tests/run.sh
bash -n install.sh uninstall.sh watch-power lib/source.sh tests/run.sh app/build.sh app/test.sh
shellcheck install.sh uninstall.sh watch-power lib/source.sh tests/run.sh app/build.sh app/test.sh
```

`app/test.sh` uses a fake service boundary plus harmless local subprocess fixtures. It covers missing `blueutil`, dependency disappearance during Apply, malformed and missing cached state, discovery and setup failures, running/stopped/loaded-failed service states, explicit rule selection, canonical service recovery, ordinary timeouts, large simultaneous output streams, descendant-held pipes, and the absence of mutations during model construction, refresh, and quit.

For deterministic visual inspection without hardware or LaunchAgent access:

```bash
"$HOME/dev/build/uncordex/gui/Uncordex.app/Contents/MacOS/Uncordex" \
  --demo \
  --screenshot "$HOME/dev/build/uncordex/gui/visual/window.png"
```

`--demo` selects an in-memory fixture adapter. It cannot invoke `install.sh`, `watch-power`, `blueutil`, `launchctl`, or physical hardware.
Add `--dark` to render the same fixture with Dark Aqua for appearance inspection.
Add `--minimum-size --long-content` to inspect wrapping and long errors at the supported minimum window size, or `--empty-setup` to inspect the explicit rule placeholder.

## Service contract

The app invokes executable URLs with argument arrays and no user-input interpolation. A fixed Bash wrapper creates a dedicated process group for each command so timeout and post-exit cleanup terminate descendants that retain output pipes. Locked pipe collectors drain stdout and stderr concurrently under one deadline. Work runs on a serial background queue, and the adapter independently rejects overlapping mutations.

- `install.sh --gui-status-plist` is versioned schema 1. It returns validated configuration, dependency availability, and readings taken during the request. It never writes setup or changes the service.
- `watch-power --status-plist` is versioned schema 1. It returns validated persisted watcher observations and explicitly marks missing, malformed, wrong-boot, or wrong-binding state invalid.
- `install.sh --discover` remains the read-only source-discovery interface.
- Preview calls `install.sh ADDRESS MODE --no-install-dependencies --dry-run`.
- Preview and Apply pass `--no-install-dependencies`. The installer checks again at execution time and fails with `brew install blueutil` guidance instead of invoking Homebrew if `blueutil` disappeared after Refresh.
- Start calls `launchctl bootstrap` for `~/Library/LaunchAgents/uk.magrathean.uncordex.watch-power.plist`.
- Stop calls `launchctl bootout` and does not delete the plist, configuration, runtime state, app files, or logs.

`launchctl print` is parsed for its observed `state` and last exit code. Running, loaded-but-not-running, stopped, and not-installed are distinct. A loaded failed job can be restarted with canonical `launchctl kickstart -k` or stopped for setup repair.

The app never launches a second watcher. Closing or quitting the app does not stop the LaunchAgent. A watcher retry phase of `paused` is displayed as automatic retry state, not as a stopped service.

## UI behavior

The native AppKit window uses a sidebar with three destinations:

- **Overview:** background service status, saved setup, latest power reading, and automatic restore state.
- **Speaker & Rule:** paired-device discovery, manual address entry, and explicit reconnection choices with behavior explanations. Preview and Save & Start stay visible below the scrollable form. Save & Start invokes the existing installer and starts the canonical service.
- **Diagnostics:** cached service observation, Bluetooth helper availability, and logs.

The View menu supports Command-1/2/3 navigation and Command-R refresh. Native controls, SF Symbols, semantic colors, and the sidebar material follow macOS appearance settings. Content and operation results scroll independently at the 760×580 minimum window size. Empty setup opens Speaker & Rule without choosing a reconnection rule. Refresh and discovery preserve draft choices; successful saving reloads the saved setup. The app delegate, window controller, and shared layout helpers are separate source files.

Fixture screenshots can select a destination with `--page 0`, `--page 1`, or `--page 2`. These flags apply only with `--demo`.

Refresh distinguishes current power/source reads from cached watcher observations. Setup offers paired-device discovery, manual Bluetooth address entry, exact saved-source choices, any external power, and disconnect only. Empty setup retains a placeholder until the user explicitly selects a rule; it never defaults to any power. The selected behavior stays visible during Preview and Apply. Apply and service changes are explicit buttons. There are no connect/disconnect controls, pairing controls, Bluetooth-radio controls, automatic dependency installation, or first-launch service activation.

When `blueutil` is absent, the app shows `brew install blueutil` and disables actions that require it. Open Logs opens `~/Library/Logs` only when that directory already exists.

## Acceptance boundary

The simulated suites and fixture rendering do not operate Bluetooth devices or the logged-in user's LaunchAgent. Universal slices and deployment metadata demonstrate build configuration, not runtime acceptance on an actual macOS 13 machine. Physical discovery, disconnect, and restoration remain separate acceptance work.
