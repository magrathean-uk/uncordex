# Troubleshooting

## The app says `blueutil` is unavailable

Install the external helper, then select **Refresh**:

```bash
brew install blueutil
```

Uncordex supports the standard Apple Silicon path `/opt/homebrew/bin/blueutil` and Intel path `/usr/local/bin/blueutil`. The app never installs Homebrew packages automatically.

## No exact source appears

Some chargers do not expose a serial, and some USB devices expose duplicate or placeholder identities. Uncordex will not guess from a model name, wattage, port, voltage, or battery serial.

Choose **Any external power** only when every charger may restore the speaker. Otherwise choose **Disconnect only**. Command-line discovery can show the exact candidates that macOS exposes:

```bash
./install.sh --discover
```

## The app shows Not installed or Stopped

**Not installed** means the canonical LaunchAgent property list does not exist. Complete **Speaker & Rule**, preview the setup, and select **Save & Start**.

**Stopped** means a configuration and property list exist but the service is not loaded. Select **Start**. A loaded job that exited is shown separately; use **Restart** or stop it before repairing setup.

## The speaker does not restore

Open **Overview** and **Diagnostics**, or inspect the saved rule and logs:

```bash
~/.local/share/uncordex/watch-power --status
tail -n 100 ~/Library/Logs/uncordex.log
tail -n 100 ~/Library/Logs/uncordex-error.log
```

Confirm that:

- the saved source is attached and AC is present;
- Bluetooth is on;
- the speaker is powered, paired, in range, and manually connectable with `blueutil`;
- the watcher initiated and verified the earlier disconnect; and
- the automatic attempt budget is not paused.

A manual reconnect consumes pending restore permission. A manual disconnect after a successful restoration is respected.

## A different charger appeared to restore the speaker

For saved-source mode, inspect the status and logs. A different charger cannot satisfy the saved source key. If the Mac remained on AC while the saved dock was connected, the dock's presence can qualify restoration; that is expected.

In any-external-power mode, any observed battery-to-AC return is eligible. Select a saved source or disconnect-only rule if that is too broad.

## No log activity

Confirm that the canonical service is loaded:

```bash
launchctl print "gui/$(id -u)/uk.magrathean.uncordex.watch-power"
```

If a legacy controller is loaded, follow [migration](migration.md). Do not operate both services against the same speaker.

## A brief unplug and replug was missed

Uncordex polls every five seconds; it does not promise event-level precision. A complete departure and return between samples may not be observed. Reconnect the source long enough for the watcher to establish two valid source samples.

## Updating the app did not update the running service

The macOS package replaces only `/Applications/Uncordex.app`. It intentionally leaves the current user's service files running. Open the updated app and select **Save & Start** to validate and replace the per-user watcher files.

A source reinstall preserves a valid rule. Use `--relearn` or supply a deliberate mode flag to change it. Use `--dry-run` first to verify the intended outcome.

## macOS blocks a downloaded package

A Developer ID signature proves who signed a package; notarization is the separate Apple malware-scanning and ticket process. The recorded 1.0.0 package was signed and timestamped but intentionally not notarized, so Gatekeeper may block a copy downloaded on another Mac.

Do not bypass Gatekeeper for a package you did not build or receive from a trusted source. Build from the reviewed source, or use a future release whose notes explicitly record successful notarization and stapling.
