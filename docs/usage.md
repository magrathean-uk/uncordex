# Usage

## The saved rule

A saved-source rule permits restoration only when external power is present and the exact source is confirmed. A dock is a presence rule: attaching the saved dock can qualify restoration even if another charger is supplying power. A different dock or charger cannot qualify it.

Any-external-power mode permits restoration on an observed battery-to-AC return. Disconnect-only mode never restores automatically.

## Ownership of a connection

Uncordex does not make a speaker permanently connected. It creates restore permission only after all of these conditions:

1. the watcher observes a valid departure;
2. the speaker was connected;
3. Uncordex successfully disconnects it; and
4. a later speaker-state query verifies it is disconnected.

A verified watcher reconnection or manual reconnection consumes that permission. A later manual disconnect is left alone until a new eligible departure and return occur.

## Observation and retries

The watcher samples power and source identity every five seconds. One valid battery observation can establish a power departure. Source disappearance and return require two consecutive valid samples; malformed or unreadable results are `unknown`, not absence.

Before every connection attempt, Uncordex rechecks the rule and Bluetooth availability. It makes at most six attempts in a five-minute return window, waiting 5, 10, 20, 40, and 60 seconds after failed attempts. Exhaustion pauses restoration until a genuine new departure-and-return cycle. Unknown samples and restarts do not create a new budget.

A source disappearing during a connection attempt stops further retries. If that attempt is verified to have connected the speaker, Uncordex performs one guarded disconnect to undo its own action.

## Status

Read the saved rule and non-secret runtime state:

```bash
~/.local/share/uncordex/watch-power --status
```

Status masks the saved source key. It does not create runtime state or perform Bluetooth actions.

## Service and logs

```bash
launchctl print "gui/$(id -u)/uk.magrathean.uncordex.watch-power"
tail -f ~/Library/Logs/uncordex.log
tail -f ~/Library/Logs/uncordex-error.log
```

Transition and error logs include Bluetooth command failures with their exit status and error text. They do not log every idle polling cycle.

## Removal

```bash
./uninstall.sh
```

This stops only the canonical Uncordex LaunchAgent and removes only its plist. Application files, configuration, state, backups, and logs remain for inspection, recovery, or a later reinstall.
