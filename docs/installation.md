# Installation

## Prerequisites

Uncordex runs in one logged-in macOS user session. It needs Bash 3.2 or newer, `ioreg`, structured `plutil` extraction, Homebrew, and [blueutil](https://github.com/toy/blueutil). The target speaker must already be paired.

Install `blueutil` using the Homebrew path appropriate to the Mac:

```bash
brew install blueutil
```

No system daemon, administrator privilege, automatic pairing, Bluetooth-radio toggle, or audio-output selection is used.

## Discover a source

Connect the dock or charger that should qualify speaker restoration, then run:

```bash
./install.sh --discover
```

Discovery prints usable entries as an index, kind, friendly label, and opaque source key. It is read-only: it does not install a LaunchAgent, write configuration, install a package, or connect/disconnect a speaker.

An exact saved source needs one of:

- an external Thunderbolt/USB4 switch UID;
- a USB hub with vendor ID, product ID, and a non-placeholder serial; or
- a power-adapter serial plus a stable family code.

Names, wattage, voltage, ports, negotiated power, and the Mac battery serial are not identities. Missing or duplicate data fails closed. If no exact identity is available, deliberately choose `--any-power` or `--disconnect-only`.

## Choose a rule

Guided setup lists paired Bluetooth devices, discovers eligible sources, previews the selected behavior, and saves the choice:

```bash
./install.sh AA-BB-CC-DD-EE-FF
```

For automation, supply an explicit rule:

```bash
./install.sh AA-BB-CC-DD-EE-FF --source SOURCE_KEY
./install.sh AA-BB-CC-DD-EE-FF --any-power
./install.sh AA-BB-CC-DD-EE-FF --disconnect-only
```

A noninteractive first installation without a rule fails. The three rule flags are mutually exclusive.

## Preview before changing anything

```bash
./install.sh AA-BB-CC-DD-EE-FF --source SOURCE_KEY --dry-run
```

A dry run validates the selection and stages the watcher, source library, configuration, and property list in a temporary directory. It does not install packages, create persistent files, stop or load a service, or operate Bluetooth.

## Updates

Running the installer again preserves a valid saved rule. To choose another rule interactively, use:

```bash
./install.sh AA-BB-CC-DD-EE-FF --relearn
```

The installer validates every staged artifact before stopping the canonical service. It backs up prior Uncordex artifacts and restores them if copying or LaunchAgent activation fails.

## Installed layout

| Purpose | Path or identifier |
| --- | --- |
| LaunchAgent | `~/Library/LaunchAgents/uk.magrathean.uncordex.watch-power.plist` |
| Watcher | `~/.local/share/uncordex/watch-power` |
| Source reader | `~/.local/share/uncordex/lib/source.sh` |
| Configuration | `${XDG_CONFIG_HOME:-~/.config}/uncordex/config` |
| Runtime state | `${XDG_STATE_HOME:-~/.local/state}/uncordex/runtime-state` |
| Install backups | `${XDG_STATE_HOME:-~/.local/state}/uncordex/install-backups/` |
| Standard log | `~/Library/Logs/uncordex.log` |
| Error log | `~/Library/Logs/uncordex-error.log` |

See [migration](migration.md) before replacing an older watcher.
