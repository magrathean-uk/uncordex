# Installation

Uncordex can be installed as a native app or directly from source. Both paths configure the same per-user LaunchAgent and watcher. The app is the normal interactive path; the source installer remains available for review, automation, and recovery.

## Requirements

- macOS 13 or newer on Apple Silicon or Intel.
- One logged-in macOS user session.
- One Bluetooth speaker already paired with the Mac.
- Homebrew and [blueutil](https://github.com/toy/blueutil).

Install the external helper first:

```bash
brew install blueutil
```

Uncordex does not bundle `blueutil`. It does not install a system daemon, pair devices, toggle the Bluetooth radio, or select an audio output.

## Install the native app

Install `Uncordex-<version>.pkg`. The package places `Uncordex.app` in `/Applications` and registers receipt `uk.magrathean.uncordex.pkg`.

The package is script-free. Installation alone does not launch the app, start a LaunchAgent, operate Bluetooth, install dependencies, or create per-user configuration. Open Uncordex after installation and use **Speaker & Rule**:

1. Select **Refresh Devices** to list paired speakers and discover stable power sources.
2. Choose the speaker or enter its Bluetooth address.
3. Choose **Saved source**, **Any external power**, or **Disconnect only**.
4. Select **Preview** and read the exact behavior.
5. Select **Save & Start** to write the per-user files and start the canonical service.

An empty setup never defaults to the broad any-power rule. If `blueutil` is unavailable, the app explains how to install it and does not invoke Homebrew itself.

See [macOS installer package](pkg.md) for build, signature, and package validation details.

## Discover a source from the command line

From a source checkout, connect the dock or charger that should qualify restoration, then run:

```bash
./install.sh --discover
```

Discovery prints each usable source as an index, kind, friendly label, and opaque key. It is read-only: it does not install a LaunchAgent, write configuration, install a package, or connect or disconnect a speaker.

An exact saved source needs one of:

- an external Thunderbolt/USB4 switch UID;
- a USB hub with vendor ID, product ID, and a non-placeholder serial; or
- a power-adapter serial plus a stable family code.

Names, wattage, voltage, ports, negotiated power, and the Mac battery serial are not identities. Missing, duplicate, malformed, or unreadable identity data fails closed. If no exact identity is available, deliberately choose any-power or disconnect-only behavior.

## Configure from the command line

Guided setup lists paired Bluetooth devices, discovers eligible sources, previews the choice, and saves it:

```bash
./install.sh AA-BB-CC-DD-EE-FF
```

For noninteractive setup, provide exactly one rule:

```bash
./install.sh AA-BB-CC-DD-EE-FF --source SOURCE_KEY
./install.sh AA-BB-CC-DD-EE-FF --any-power
./install.sh AA-BB-CC-DD-EE-FF --disconnect-only
```

A first noninteractive installation without a rule fails. Preview the operation without persistent changes with:

```bash
./install.sh AA-BB-CC-DD-EE-FF --source SOURCE_KEY --dry-run
```

A dry run validates and stages the watcher, source library, configuration, and property list in a temporary directory. It does not install dependencies, create persistent files, stop or load a service, or operate Bluetooth.

## Update an existing installation

Installing a newer package replaces only `/Applications/Uncordex.app`. It preserves the current user's configuration, runtime state, logs, backups, and LaunchAgent. Open the new app and select **Save & Start** when you want the running service files updated from the new bundle.

Running `install.sh` again preserves a valid saved rule. To choose another rule interactively, use:

```bash
./install.sh AA-BB-CC-DD-EE-FF --relearn
```

The source installer validates every staged artifact before stopping the canonical service. It backs up prior Uncordex artifacts and restores them if copying or LaunchAgent activation fails.

## Installed layout

| Purpose | Path or identifier |
| --- | --- |
| Native app | `/Applications/Uncordex.app` |
| Package receipt | `uk.magrathean.uncordex.pkg` |
| LaunchAgent | `~/Library/LaunchAgents/uk.magrathean.uncordex.watch-power.plist` |
| Watcher | `~/.local/share/uncordex/watch-power` |
| Source reader | `~/.local/share/uncordex/lib/source.sh` |
| Configuration | `${XDG_CONFIG_HOME:-~/.config}/uncordex/config` |
| Runtime state | `${XDG_STATE_HOME:-~/.local/state}/uncordex/runtime-state` |
| Install backups | `${XDG_STATE_HOME:-~/.local/state}/uncordex/install-backups/` |
| Standard log | `~/Library/Logs/uncordex.log` |
| Error log | `~/Library/Logs/uncordex-error.log` |

Read [migration](migration.md) before replacing an older speaker watcher. Two controllers must not operate the same speaker.
