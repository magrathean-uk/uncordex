# Architecture

## Components

| Component | Responsibility |
| --- | --- |
| `install.sh` | Validates setup, discovers source identities, writes configuration, stages artifacts, and manages the canonical per-user LaunchAgent. |
| `watch-power` | Owns connection permission, samples state, schedules bounded retries, persists runtime state, and provides `--status`. |
| `lib/source.sh` | Reads hardware snapshots, offers unique saved-source candidates, and classifies fresh source presence as `match`, `absent`, or `unknown`. |
| `uninstall.sh` | Stops the canonical LaunchAgent and leaves recovery data intact. |
| `tests/run.sh` | Uses fixture hardware plus fake Bluetooth, clock, and LaunchAgent boundaries to exercise real decisions without controlling physical hardware. |

## Source identity

The source library accepts only stable identities:

- external Thunderbolt/USB4 switch UID;
- serialized USB hub vendor/product/serial tuple;
- serialized power adapter with stable family code.

It hashes canonical fields into opaque keys. Friendly labels are never identity inputs. Missing, duplicate, malformed, or reader-failure data produces no candidate or `unknown`; it never becomes a broad match.

## Connection ownership

The watcher separates observing power from permission to reconnect:

```text
confirmed departure
  -> watcher disconnect succeeds and speaker is verified disconnected
  -> pending ownership
  -> fresh eligible return plus Bluetooth availability
  -> one scheduled connection attempt
  -> verified reconnect or manual reconnect consumes ownership
```

A startup baseline, unknown reading, process restart, changed rule, malformed state, or reboot cannot invent ownership.

## Runtime state

Configuration stores the speaker, selected mode, and source rule. Runtime state stores a schema, boot ID, rule binding, phase, attempt timing, last confirmed observations, and departure flag. State is written atomically with current-user permissions.

Only same-boot pending state can resume, and only after fresh observations. Interrupted disconnects are never upgraded into restore permission.

## Failure behavior

Reader failures are unknown. Connection commands are bounded and verified before and after action. Retry scheduling is finite and nonblocking. Installation stages scripts, configuration, and plist before stopping the existing canonical service; it restores backups if copy or activation fails.

The architecture deliberately excludes permanent connection enforcement, multiple-speaker profiles, automatic pairing, Bluetooth-radio control, cloud services, and telemetry.
