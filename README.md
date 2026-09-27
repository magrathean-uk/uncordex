<h1 align="center">Uncordex</h1>

<p align="center">A native macOS controller that disconnects one paired Bluetooth speaker when your saved desk setup departs, then restores only a connection it previously disconnected.</p>

<p align="center">
  <a href="docs/index.md">Documentation</a>
</p>

## Overview

Uncordex combines a native AppKit app with a per-user LaunchAgent. It runs locally on macOS 13 or newer, on Apple Silicon and Intel, keeps configuration on the Mac, and uses [blueutil](https://github.com/toy/blueutil) to control a speaker already paired with macOS. It has no account, cloud service, telemetry, automatic pairing, Bluetooth-radio control, audio-output switching, or system daemon.

## Features

- Controls one already-paired Bluetooth speaker; manual connections and disconnections are always respected.
- Three reconnection rules: a saved power source, any external power, or disconnect only.
- Restores a connection only after verifying that Uncordex itself disconnected it, rather than continually forcing a preferred state.
- Native AppKit app with Overview, Speaker & Rule, and Diagnostics views.
- Script-free macOS Installer package that installs the universal app in `/Applications`.

## How it works

1. Choose one paired Bluetooth speaker.
2. Choose a reconnection rule: one saved power source, any external power, or disconnect only.
3. The watcher samples power and source identity every five seconds.
4. After a confirmed departure, it disconnects the speaker and records ownership only after verifying that the disconnect succeeded.
5. When the selected setup returns, it reconnects only while that ownership remains valid.

### Reconnection rules

- **Saved source:** reconnect while AC is present and an exact saved Thunderbolt/USB4 device, serialized USB hub, or serialized power adapter is present.
- **Any external power:** reconnect after an observed battery-to-AC return. Use this only if every charger is acceptable.
- **Disconnect only:** disconnect on departure and never reconnect automatically.

A saved dock is a presence rule. If another charger already keeps the Mac on AC, attaching the saved dock can make restoration eligible. A different charger cannot satisfy the saved source identity.

## Getting started

### Requirements

- macOS 13 or newer on Apple Silicon or Intel.
- A logged-in macOS user session.
- A Bluetooth speaker already paired with the Mac.
- Homebrew and `blueutil`, installed separately:

  ```bash
  brew install blueutil
  ```

### Install the app

Build the app and macOS package from source using the steps in [package guidance](docs/pkg.md). If you use a published package, check its release notes for the artifact and its stated signing status. After installation, open **Uncordex** from Applications, then open **Speaker & Rule**. Find paired devices and eligible sources, choose a speaker and rule, select **Preview**, then select **Save & Start**.

The package places the app in `/Applications`. Package installation alone does not start a service, control Bluetooth, install dependencies, or create user configuration. App upgrades preserve existing configuration, state, logs, and LaunchAgent files. See [installation](docs/installation.md) and [package details](docs/pkg.md).

### Install from source

Connect the dock or charger that should qualify restoration, then discover stable source identities:

```bash
git clone https://github.com/magrathean-uk/uncordex.git
cd uncordex
brew install blueutil
./install.sh --discover
```

Discovery is read-only. Start guided setup with the speaker's Bluetooth address:

```bash
./install.sh AA-BB-CC-DD-EE-FF
```

For noninteractive setup, choose exactly one rule:

```bash
./install.sh AA-BB-CC-DD-EE-FF --source SOURCE_KEY
./install.sh AA-BB-CC-DD-EE-FF --any-power
./install.sh AA-BB-CC-DD-EE-FF --disconnect-only
```

Preview source setup without persistent writes, service changes, or Bluetooth actions:

```bash
./install.sh AA-BB-CC-DD-EE-FF --source SOURCE_KEY --dry-run
```

### Status and removal

The app's **Overview** shows service status, saved setup, current power/source readings, and automatic restore state. **Diagnostics** shows watcher observations, dependency status, and log access. From a source checkout or installed service, inspect status and logs with:

```bash
~/.local/share/uncordex/watch-power --status
launchctl print "gui/$(id -u)/uk.magrathean.uncordex.watch-power"
tail -f ~/Library/Logs/uncordex.log
tail -f ~/Library/Logs/uncordex-error.log
```

Use the app's **Stop** control to stop the service while preserving its files. From a source checkout, this command stops the canonical LaunchAgent and removes its property list:

```bash
./uninstall.sh
```

Configuration, runtime state, backups, and logs remain available after removal. See [usage](docs/usage.md) and [troubleshooting](docs/troubleshooting.md).

## Documentation

- [Documentation index](docs/index.md)
- [Installation](docs/installation.md)
- [Usage](docs/usage.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Migration from older watchers](docs/migration.md)
- [Architecture](docs/architecture.md)
- [Development and verification](docs/development.md)
- [Release process](docs/releasing.md)
- [Changelog](CHANGELOG.md)
- [Contributing](.github/CONTRIBUTING.md)
- [Security policy](.github/SECURITY.md)
- [Support](.github/SUPPORT.md)

Automated suites use fixture hardware snapshots and substitute Bluetooth, clock, process, and LaunchAgent boundaries. They do not touch real devices or services and cannot prove behavior on a particular Mac, dock, charger, or speaker. The [2026-09-09 live acceptance record](docs/testing/2026-09-09-live-acceptance.md) covers one Bose/ASUS setup on one Mac. macOS 13 runtime behavior, Intel runtime behavior, sleep/wake, reboot/login, and other hardware combinations remain separate acceptance work.

## Licence

Uncordex is open source under the MIT licence. See [LICENSE](LICENSE) and [third-party notices](THIRD_PARTY_NOTICES.md). Contributions: see [Contributing](.github/CONTRIBUTING.md).

<sub>© 2026 MAGRATHEAN UK LTD · <a href="https://github.com/magrathean-uk/.github/blob/main/LEGAL.md">Legal</a></sub>
