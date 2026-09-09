# Troubleshooting

## No exact source appears in discovery

Some chargers do not expose a serial, and some USB devices expose duplicate or placeholder identities. Uncordex will not guess from a model name, wattage, port, voltage, or battery serial.

Choose `--any-power` only if every external charger may restore the speaker. Otherwise choose `--disconnect-only`.

## The speaker does not restore

Check the saved rule, current phase, and logs:

```bash
~/.local/share/uncordex/watch-power --status
tail -n 100 ~/Library/Logs/uncordex.log
tail -n 100 ~/Library/Logs/uncordex-error.log
```

Then confirm all of the following:

- the saved source is attached and AC is present;
- Bluetooth is on;
- the speaker is powered, paired, in range, and manually connectable with `blueutil`;
- the watcher itself initiated and verified the earlier disconnect;
- the automatic attempt budget is not paused.

A manual reconnect consumes the pending restore permission, by design. A manual disconnect after a successful restoration is also respected.

## A different charger restored the speaker

For saved-source mode, inspect the status and logs. A different charger cannot satisfy the saved source key. If the Mac remained on AC while the saved dock was connected, the dock’s presence can qualify restoration; that is expected.

If any-external-power mode is selected, any observed battery-to-AC return is eligible. Reinstall with a saved source or disconnect-only rule if that is too broad.

## No log activity

Confirm the canonical service is loaded:

```bash
launchctl print "gui/$(id -u)/uk.magrathean.uncordex.watch-power"
```

If a legacy controller is still loaded, follow [migration](migration.md). Do not operate both.

## Brief unplug/replug was missed

Uncordex polls; it does not promise event-level precision. A complete departure and return between samples may not be observed. Reconnect the source long enough for the watcher to establish two valid source samples.

## Reinstalling changed nothing

A normal reinstall preserves a valid rule. Use `--relearn` or supply a deliberate mode flag to change the rule. Use `--dry-run` first to verify the intended outcome.
