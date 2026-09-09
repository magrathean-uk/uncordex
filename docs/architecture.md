# Architecture

Uncordex has two user-facing installation paths around one watcher implementation. The native app provides setup, status, and service controls. The source scripts provide the same operations directly. Both manage one per-user LaunchAgent; the macOS package only installs the app bundle.

## Components

| Component | Responsibility |
| --- | --- |
| `app/` | Native AppKit interface, process boundary, setup model, service controls, and fixture-only visual mode. |
| `packaging/` | Script-free macOS Installer package assembly and validation. |
| `install.sh` | Validates setup, discovers source identities, writes configuration, stages service files, and manages the canonical LaunchAgent. |
| `watch-power` | Owns connection permission, samples state, schedules bounded retries, persists runtime state, and provides text and property-list status. |
| `lib/source.sh` | Reads hardware snapshots, offers unique candidates, and classifies fresh source presence as `match`, `absent`, or `unknown`. |
| `uninstall.sh` | Stops the canonical LaunchAgent and leaves recovery data intact. |
| `tests/run.sh` | Exercises watcher and installer decisions with substituted hardware, Bluetooth, clock, and LaunchAgent boundaries. |
| `app/test.sh` | Compiles the app model against fake service and subprocess boundaries. |
| `packaging/test.sh` | Rejects invalid packages and validates a supplied finished artifact. |

## App and service boundary

The app contains reviewed copies of the installer, uninstaller, watcher, source reader, version, license, and third-party notice. It invokes fixed executable URLs with argument arrays. User-entered addresses and discovered keys are passed as arguments, not interpolated into shell source.

A dedicated process group bounds every app-launched command. Standard output and error are drained concurrently, deadlines terminate descendants that keep pipes open, and the adapter rejects overlapping mutations.

The app reads versioned property-list interfaces:

- `install.sh --gui-status-plist` validates saved configuration and returns current dependency, power, and source readings without changing setup or service state.
- `watch-power --status-plist` returns cached runtime observations and marks missing, malformed, wrong-boot, or wrong-binding state invalid.

`launchctl print` is parsed only at the job's top level so nested coalition state cannot replace the actual service state.

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

The macOS package is non-relocatable and installs only `/Applications/Uncordex.app`. It contains no installer scripts and makes no user-session changes.

**Save & Start** or `install.sh` stages service files and configuration before stopping the existing canonical job. Validation failures leave the current installation untouched. Activation failure restores the backup and reloads the previous job when it was already active.

The architecture excludes permanent connection enforcement, multiple-speaker profiles, automatic pairing, Bluetooth-radio control, automatic dependency installation, cloud services, accounts, and telemetry.
