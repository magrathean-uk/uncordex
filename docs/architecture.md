# Architecture

Uncordex is one command-line tool around one watcher. The `uncordex` command handles setup, status and service control. A per-user LaunchAgent runs the watcher.

## Components

| Component | Responsibility |
| --- | --- |
| `uncordex` | The CLI: setup, status, start, stop, restart, logs, device and source listing, uninstall. Validates input, writes configuration, stages service files and manages the canonical LaunchAgent. |
| `install.sh` | One-line installer: copies files to the data directory and links the command. Does not perform setup. |
| `watch-power` | Owns connection permission, samples state, schedules bounded retries, persists runtime state, and provides text status. |
| `lib/source.sh` | Reads hardware snapshots, offers unique candidates, and classifies fresh source presence as `match`, `absent`, or `unknown`. |
| `tests/run.sh` | Exercises watcher and CLI decisions with substituted hardware, Bluetooth, clock, and LaunchAgent boundaries. |

## Source identity

The source library accepts only stable identities:

- external Thunderbolt/USB4 switch UID;
- serialized USB hub vendor/product/serial tuple; or
- serialized power adapter with stable family code.

It hashes canonical fields into opaque keys. Friendly labels are never identity inputs. Missing, duplicate, malformed, or unreadable data produces no candidate or `unknown`; it never becomes a broad match.

## Connection ownership

```text
confirmed departure
  -> watcher disconnect succeeds and verifies the speaker is disconnected
  -> pending ownership
  -> fresh eligible return plus Bluetooth availability
  -> one scheduled connection attempt
  -> verified watcher reconnect or manual reconnect consumes ownership
```

A startup baseline, unknown reading, process restart, changed rule, malformed state, or reboot cannot invent ownership.

## Runtime state

Configuration stores the speaker, selected mode, and source rule. Runtime state stores a schema, boot ID, rule binding, phase, attempt timing, last confirmed observations, and departure flag. State is written atomically with current-user permissions.

Only same-boot pending state can resume, and only after fresh observations. Interrupted disconnects are never upgraded into restore permission.

## Installation boundaries

`install.sh` copies `uncordex`, `watch-power`, `lib/source.sh` and `VERSION` to `~/.local/share/uncordex` (or `$XDG_DATA_HOME/uncordex`) and links `~/.local/bin/uncordex`. It installs `blueutil` with Homebrew when missing, unless `--no-install-dependencies` is given. It does not configure a speaker or create a service.

`uncordex setup` stages service files and configuration before stopping the existing canonical job. Validation failures leave the current installation untouched. Activation failure restores the backup and reloads the previous job when it was already active.

`uncordex stop` disables the LaunchAgent so it stays off across logins until `uncordex start`. `uncordex uninstall` removes the service and command but keeps configuration, state and logs; `--purge` deletes those too.

The architecture excludes permanent connection enforcement, multiple-speaker profiles, automatic pairing, Bluetooth-radio control, cloud services, accounts, and telemetry.
