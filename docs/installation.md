# Installation

Uncordex can be installed as a native app or from a source checkout. The app provides the interactive setup. Both paths use a per-user LaunchAgent and the same watcher.

## Requirements

- macOS 13 or newer on Apple Silicon or Intel.
- A logged-in macOS user session.
- A Bluetooth speaker already paired with the Mac.
- Homebrew and [blueutil](https://github.com/toy/blueutil).

Install `blueutil` before setup:

```bash
brew install blueutil
```

The app and package do not bundle or install `blueutil`. The source installer can install it with Homebrew when needed; pass `--no-install-dependencies` to prevent that and receive setup guidance instead. Uncordex does not pair devices, toggle the Bluetooth radio, select an audio output, or install a system daemon.

## Install the native app

Build the app and package from source using [package guidance](pkg.md), or use a published artifact whose release notes identify it and state its signing status. Install the package, then open Uncordex from `/Applications`. The package places `Uncordex.app` in that directory and registers receipt `uk.magrathean.uncordex.pkg`.

Package installation alone does not launch the app, start a LaunchAgent, control Bluetooth, install dependencies, or create per-user configuration. In the app:

1. Open **Speaker & Rule** and select **Find Devices & Sources**.
2. Choose a paired speaker or enter its Bluetooth address.
3. Choose **Saved source**, **Any external power**, or **Disconnect only**.
4. Select **Preview** and review the described behavior.
5. Select **Save & Start** to save per-user files and start the canonical service.

An empty setup has no default reconnection rule. If `blueutil` is missing, the app gives installation guidance and does not invoke Homebrew.

See [package details](pkg.md) for package build, signature, validation, and removal information.

## Discover a source from a checkout

Connect the dock or charger that should qualify restoration, then run:

```bash
./install.sh --discover
```

Discovery prints usable candidates with an index, kind, label, and opaque key. It does not install a LaunchAgent, write configuration, install a package, or connect or disconnect a speaker.

An exact saved source requires one of:

- an external Thunderbolt/USB4 switch UID;
- a USB hub with vendor ID, product ID, and a non-placeholder serial; or
- a power-adapter serial and stable family code.

Names, wattage, voltage, ports, negotiated power, and the Mac battery serial are not identities. Missing, duplicate, malformed, or unreadable identity data is not treated as a match. If macOS cannot provide a stable identity, choose any-power or disconnect-only deliberately.

## Configure from a checkout

Guided setup discovers paired devices, offers eligible sources, previews the choice, and saves it:

```bash
./install.sh AA-BB-CC-DD-EE-FF
```

For noninteractive setup, provide exactly one rule:

```bash
./install.sh AA-BB-CC-DD-EE-FF --source SOURCE_KEY
./install.sh AA-BB-CC-DD-EE-FF --any-power
./install.sh AA-BB-CC-DD-EE-FF --disconnect-only
```

A first noninteractive installation without a rule fails. Preview without persistent changes using:

```bash
./install.sh AA-BB-CC-DD-EE-FF --source SOURCE_KEY --dry-run
```

The dry run stages and validates files in a temporary directory. It does not install dependencies, create persistent files, stop or load a service, or operate Bluetooth.

## Update an installation

Installing a newer package replaces only `/Applications/Uncordex.app`. It preserves per-user configuration, runtime state, logs, backups, and LaunchAgent files. Open the updated app and select **Save & Start** when you want its bundled service files applied to the running installation.

Running `install.sh` again preserves a valid saved rule. To choose another rule interactively, use:

```bash
./install.sh AA-BB-CC-DD-EE-FF --relearn
```

The source installer validates staged artifacts before stopping the canonical service. It backs up prior Uncordex files and restores them if copying or LaunchAgent activation fails.

## Installed paths

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

Read [migration](migration.md) before replacing an older watcher. Two controllers must not operate the same speaker.
