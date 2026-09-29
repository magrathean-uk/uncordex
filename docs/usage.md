# Usage

## App sections

Open Uncordex from `/Applications`.

- **Overview** shows background service state, saved speaker and rule, current power/source readings, and automatic restore state.
- **Speaker & Rule** discovers paired speakers and eligible sources, lets you choose a rule, previews behavior, and saves or updates the service.
- **Diagnostics** shows cached watcher observations, `blueutil` availability, operation results, and log access.

Refresh reads current status. It does not connect or disconnect the speaker or change the service. Closing or quitting the app leaves the LaunchAgent running.

## Choose a rule

A saved-source rule permits restoration only while AC is present and the exact saved source is confirmed. A saved dock is a presence rule: attaching it can qualify restoration even if another charger supplies power. A different dock or charger cannot satisfy its key.

Any-external-power mode permits restoration after an observed battery-to-AC return. Disconnect-only mode never restores automatically. Empty setup has no default rule. Review **Preview** before **Save & Start**.

## Connection ownership

Uncordex creates restore permission only after it observes a valid departure, finds the speaker connected, successfully disconnects it, and then verifies it is disconnected. A watcher reconnection or manual reconnection consumes that permission. A later manual disconnect is left alone until another eligible departure and return.

## Sampling and retries

The watcher samples power and source identity every five seconds. A valid battery observation can establish a power departure. Saved-source disappearance and return require two consecutive valid samples. Unreadable or malformed results are treated as unknown, not as absence.

Before each connection attempt, Uncordex rechecks the rule and Bluetooth availability. It makes at most six attempts in a five-minute eligible-return window. After failures, waits are 5, 10, 20, 40, and 60 seconds. Exhaustion pauses restoration until a genuine new departure and return. Unknown readings and service restarts do not create a new attempt budget.

If a source disappears during a connection attempt, later retries stop. If that attempt is verified to have connected the speaker, Uncordex makes one guarded disconnect to undo its own action.

## Service controls

**Start** loads a configured LaunchAgent. If a loaded service has exited, the app offers **Restart**. **Stop** unloads the service while preserving its property list, configuration, state, app, and logs.

The app distinguishes Running, Loaded but not running, Stopped, and Not installed. A paused automatic retry phase does not mean the service has stopped.

## Command-line status

Read the saved rule and runtime status with:

```bash
"${XDG_DATA_HOME:-$HOME/.local/share}/uncordex/watch-power" --status
```

Status masks the source key, but includes the saved speaker address and source label. Review and redact output before sharing it. The command does not create runtime state or operate Bluetooth. Inspect the LaunchAgent and logs with:

```bash
launchctl print "gui/$(id -u)/uk.magrathean.uncordex.watch-power"
tail -f ~/Library/Logs/uncordex.log
tail -f ~/Library/Logs/uncordex-error.log
```

Transition and error logs include Bluetooth command failures with exit status and error text. They do not record every idle polling cycle.

## Removal

Stop the service in the app before removing `/Applications/Uncordex.app`. From a source checkout or the app's bundled Service directory, this command stops the canonical service and removes its LaunchAgent property list:

```bash
./uninstall.sh
```

Configuration, runtime state, backups, and logs remain available for recovery or later reinstall. See [package removal](pkg.md#remove) for the app and receipt boundary.
