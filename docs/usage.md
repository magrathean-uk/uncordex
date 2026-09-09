# Usage

## App overview

Open Uncordex from `/Applications`. The sidebar separates routine status from setup and diagnostics:

- **Overview** shows whether the background service is running, the saved speaker and rule, the current power/source reading, and the automatic restore phase.
- **Speaker & Rule** discovers paired speakers and eligible sources, previews a deliberate rule, and saves or updates the service.
- **Diagnostics** shows cached watcher observations, `blueutil` availability, operation results, and log access.

Refresh reads current state. It does not connect or disconnect the speaker or change the service. Closing or quitting the app leaves the LaunchAgent running.

## Choose a rule

A saved-source rule permits restoration only when AC is present and the exact source is confirmed. A saved dock is a presence rule: attaching it can qualify restoration even if another charger already supplies power. A different dock or charger cannot satisfy its key.

Any-external-power mode permits restoration after an observed battery-to-AC return. Disconnect-only mode never restores automatically.

Use **Preview** before **Save & Start**. The preview identifies the selected speaker and states when reconnection will be allowed. Empty setup has no default rule.

## Connection ownership

Uncordex creates restore permission only after all of these conditions:

1. the watcher observes a valid departure;
2. the speaker was connected;
3. Uncordex successfully disconnects it; and
4. a later query verifies that it is disconnected.

A verified watcher reconnection or manual reconnection consumes that permission. A later manual disconnect is left alone until a new eligible departure and return occur.

## Observation and retries

The watcher samples power and source identity every five seconds. One valid battery observation can establish a power departure. Source disappearance and return require two consecutive valid samples. Malformed or unreadable results are `unknown`, not absence.

Before every connection attempt, Uncordex rechecks the rule and Bluetooth availability. It makes at most six attempts in a five-minute return window, waiting 5, 10, 20, 40, and 60 seconds after failed attempts. Exhaustion pauses restoration until a genuine new departure-and-return cycle. Unknown samples and restarts do not create a new budget.

A source disappearing during a connection attempt stops later retries. If that attempt is verified to have connected the speaker, Uncordex performs one guarded disconnect to undo its own action.

## Service controls

**Start** loads a configured LaunchAgent. If a loaded service has exited, **Restart** uses the canonical launchd job. **Stop** unloads the service while preserving its property list, configuration, state, app, and logs.

The app distinguishes Running, Loaded but not running, Stopped, and Not installed. A paused automatic retry phase does not mean the service has stopped.

## Command-line status

Read the saved rule and non-secret runtime state with:

```bash
~/.local/share/uncordex/watch-power --status
```

Status masks the source key. It does not create runtime state or operate Bluetooth.

Inspect the LaunchAgent and logs with:

```bash
launchctl print "gui/$(id -u)/uk.magrathean.uncordex.watch-power"
tail -f ~/Library/Logs/uncordex.log
tail -f ~/Library/Logs/uncordex-error.log
```

Transition and error logs include Bluetooth command failures with exit status and error text. They do not record every idle polling cycle.

## Removal

Stop the service in the app before removing `/Applications/Uncordex.app`. To stop the canonical service and remove only its LaunchAgent property list from a source checkout or the app's bundled Service directory, run:

```bash
./uninstall.sh
```

Configuration, runtime state, backups, and logs remain available for inspection, recovery, or a later reinstall. See [package removal](pkg.md#removal) for the app and receipt boundary.
