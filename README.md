# Uncordex

Uncordex is a per-user macOS service that disconnects one Bluetooth speaker when a saved desk setup departs, then restores only the connection it previously disconnected.

It uses [blueutil](https://github.com/toy/blueutil) and a LaunchAgent. It has no daemon, account, cloud service, telemetry, automatic pairing, Bluetooth-radio control, or audio-output switching.

## Why source-aware

A power transition alone cannot tell one charger or dock from another. During setup, choose one explicit rule:

- **Saved source — recommended:** reconnect only while AC is present and a saved Thunderbolt/USB4 dock, serialized USB hub, or serialized power adapter matches.
- **Any external power:** reconnect after any battery-to-AC return. Use only when you deliberately accept every charger.
- **Disconnect only:** disconnect on departure and never reconnect automatically.

A dock rule identifies device presence, not the currently active power cable. If another charger already keeps the Mac on AC, attaching the saved dock can still make restoration eligible. A different charger cannot satisfy a saved-source rule.

## Requirements

- macOS with `ioreg`, structured `plutil` extraction, and Bash 3.2 or later.
- Homebrew and `blueutil`.
- One speaker already paired with the Mac.
- A logged-in macOS user session.

Apple Silicon (`/opt/homebrew`) and Intel (`/usr/local`) Homebrew paths are supported.

## Quick start

First, connect the dock or charger you want to save and discover whether macOS exposes a unique identity:

```bash
git clone https://github.com/magrathean-uk/uncordex.git
cd uncordex
brew install blueutil
./install.sh --discover
```

Discovery is read-only. It does not install a service or operate Bluetooth.

For guided installation:

```bash
./install.sh AA-BB-CC-DD-EE-FF
```

For noninteractive installation, choose a rule deliberately:

```bash
./install.sh AA-BB-CC-DD-EE-FF --source SOURCE_KEY
./install.sh AA-BB-CC-DD-EE-FF --any-power
./install.sh AA-BB-CC-DD-EE-FF --disconnect-only
```

Preview an installation without packages, writes, service changes, or Bluetooth actions:

```bash
./install.sh AA-BB-CC-DD-EE-FF --source SOURCE_KEY --dry-run
```

## How it behaves

- Polls power and source identity every five seconds.
- Requires two valid source observations to confirm a saved source’s disappearance or return.
- Disconnects a connected speaker on a confirmed AC-to-battery transition. A saved dock disappearing while another charger maintains AC is also a departure.
- Restores only after Uncordex successfully disconnected and verified that same speaker; manual connections and disconnections remain respected.
- Attempts at most six reconnections in a five-minute eligible return window, using 5, 10, 20, 40, and 60-second backoff.
- Fails closed on unknown hardware readings, malformed state, changed rules, and reboot. Same-boot restarts retain a pending retry budget only after fresh observations.
- Never enables Bluetooth, pairs devices, changes audio output, or continually enforces a connection.

## Status and removal

Read the rule and current state:

```bash
~/.local/share/uncordex/watch-power --status
```

Inspect the service and logs:

```bash
launchctl print "gui/$(id -u)/uk.magrathean.uncordex.watch-power"
tail -f ~/Library/Logs/uncordex.log
tail -f ~/Library/Logs/uncordex-error.log
```

Remove only the canonical Uncordex LaunchAgent:

```bash
./uninstall.sh
```

Application files, configuration, state, backups, and logs remain for recovery or reinstall.

## Documentation

- [Installation](docs/installation.md)
- [Usage and operating model](docs/usage.md)
- [Migrating from older watchers](docs/migration.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Architecture](docs/architecture.md)
- [Development and verification](docs/development.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Release process](docs/releasing.md)
- [Changelog](CHANGELOG.md)
- [MIT License](LICENSE)
- [Third-party notices](THIRD_PARTY_NOTICES.md)

## Acceptance boundary

The automated suite uses fixture hardware snapshots and substituted Bluetooth, clock, and LaunchAgent boundaries. A passing suite is simulated evidence; it is not proof that a particular Mac, dock, charger, or Bluetooth speaker will accept a connection. Perform physical acceptance deliberately after installation.
