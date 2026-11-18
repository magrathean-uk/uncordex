<h1 align="center">Uncordex</h1>

<p align="center">Disconnects your Bluetooth speaker when you leave your desk and reconnects it when you come back.</p>

<p align="center">
  <a href="docs/index.md">Documentation</a>
</p>

Uncordex is a small command-line tool for macOS. A per-user background service watches your power and dock, disconnects one already-paired Bluetooth speaker when you leave, and reconnects it when you return. Everything stays on your Mac: no account, cloud service or telemetry.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/magrathean-uk/uncordex/main/install.sh | bash
```

Or from a clone:

```bash
git clone https://github.com/magrathean-uk/uncordex.git && cd uncordex && ./install.sh
```

The installer copies Uncordex to `~/.local/share/uncordex`, links `~/.local/bin/uncordex`, and installs `blueutil` with Homebrew if it is missing. It does not change your speaker settings.

## Quick start

```bash
uncordex setup     # pick your speaker and a rule, then start it
uncordex status    # see what it is doing
```

## Commands

| Command | What it does |
| --- | --- |
| `uncordex setup` | Pick your speaker and rule, then start the service |
| `uncordex status` | Service, speaker, power and restore state (also plain `uncordex`) |
| `uncordex stop` | Turn it off; it stays off until `uncordex start` |
| `uncordex start` | Turn it back on |
| `uncordex restart` | Restart the background service |
| `uncordex logs [-f]` | Show recent log lines; `-f` keeps following |
| `uncordex devices` | List paired Bluetooth devices |
| `uncordex sources` | List docks and chargers Uncordex can recognise |
| `uncordex uninstall` | Remove the service and command; keep settings |
| `uncordex uninstall --purge` | Also delete settings, state and logs |

Setup takes the speaker as a number from `uncordex devices` or its address, plus one rule:

| Rule | Behaviour |
| --- | --- |
| `--source N` | Reconnect when dock or charger N from `uncordex sources` is attached. Recommended. |
| `--any-power` | Reconnect whenever the Mac is on any power. |
| `--disconnect-only` | Disconnect when you leave; never reconnect. |

Other setup options: `--dry-run` (show what would happen, change nothing) and `-y`, `--yes` (do not ask for confirmation).

## How it behaves

- It samples power and dock state every 5 seconds.
- It disconnects the speaker only after a confirmed departure.
- It reconnects only a connection it disconnected itself.
- Manual connects and disconnects are respected.
- It makes at most 6 reconnect attempts in 5 minutes.

## Examples

```bash
uncordex setup                                   # guided, with numbered choices
uncordex setup 1 --source 1 --yes                # non-interactive
uncordex setup AA-BB-CC-DD-EE-FF --any-power     # by address
uncordex setup 1 --source 1 --dry-run            # preview only
uncordex stop                                    # off, and stays off across logins
uncordex start
uncordex logs -f
uncordex uninstall                               # keeps your settings
uncordex uninstall --purge                       # removes everything
```

## Requirements

- macOS 13 or newer, on Apple Silicon or Intel.
- A Bluetooth speaker already paired with the Mac.
- Homebrew, for `blueutil`. `install.sh` installs `blueutil` automatically.

The first time, macOS may ask to allow Bluetooth access for your terminal app. If it was blocked, allow it in System Settings > Privacy & Security > Bluetooth.

## Documentation

See the [documentation index](docs/index.md) for troubleshooting, migration, architecture and development notes.

## Licence

Uncordex is open source under the MIT licence. See [LICENSE](LICENSE) and [third-party notices](THIRD_PARTY_NOTICES.md). Contributions: see [Contributing](.github/CONTRIBUTING.md).

<sub>© 2026 MAGRATHEAN UK LTD · <a href="https://github.com/magrathean-uk/.github/blob/main/LEGAL.md">Legal</a></sub>
