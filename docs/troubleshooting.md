# Troubleshooting

## The app says `blueutil` is unavailable

Install the external helper, then refresh status:

```bash
brew install blueutil
```

Uncordex checks the standard Apple Silicon path `/opt/homebrew/bin/blueutil` and Intel path `/usr/local/bin/blueutil`. The app does not install Homebrew packages automatically.

## No exact source appears

Some chargers do not expose a serial, and some USB devices expose duplicate or placeholder identities. Uncordex does not infer identity from a model name, wattage, port, voltage, or battery serial.

Choose **Any external power** only when every charger may restore the speaker. Otherwise choose **Disconnect only**. To inspect candidates from a source checkout:

```bash
./install.sh --discover
```

## The app says Not installed or Stopped

**Not installed** means the canonical LaunchAgent property list is missing. Complete **Speaker & Rule**, preview the setup, and select **Save & Start**.

**Stopped** means configuration and a property list exist but the service is not loaded. Select **Start**. If a loaded service has exited, use **Restart** or stop it before correcting setup.

## The speaker does not restore

Check **Overview** and **Diagnostics**, or inspect status and logs:

```bash
"${XDG_DATA_HOME:-$HOME/.local/share}/uncordex/watch-power" --status
tail -n 100 ~/Library/Logs/uncordex.log
tail -n 100 ~/Library/Logs/uncordex-error.log
```

Confirm the saved source is attached and AC is present, Bluetooth is on, and the speaker is powered, paired, in range, and manually connectable with `blueutil`. Restoration permission exists only if the watcher initiated and verified the earlier disconnect. A manual reconnect consumes pending permission. Automatic retries may be paused after their attempt budget expires.

## A different charger appeared to restore the speaker

In saved-source mode, a different charger cannot satisfy the saved source key. If the Mac remained on AC while the saved dock was connected, the dock's presence can qualify restoration. In any-external-power mode, any observed battery-to-AC return is eligible. Choose a saved-source or disconnect-only rule if that is too broad.

## There is no log activity

Confirm that the canonical service is loaded:

```bash
launchctl print "gui/$(id -u)/uk.magrathean.uncordex.watch-power"
```

If a legacy controller is loaded, follow [migration](migration.md). Do not run both services against the same speaker.

## A brief unplug and replug was missed

Uncordex polls every five seconds and cannot guarantee event-level precision. A complete departure and return between samples may go unseen. Keep the source disconnected long enough for the watcher to confirm the change.

## Updating the app did not update the running service

The macOS package replaces only `/Applications/Uncordex.app`; it leaves current per-user service files in place. Open the updated app and select **Save & Start** to validate and replace the bundled per-user watcher files.

A source reinstall preserves a valid rule. Use `--relearn` or a deliberate mode flag to change it. Use `--dry-run` first to preview the result.

## macOS blocks a package

Check the instructions and signing or notarization status published for the exact package artifact you received. Those properties can differ between builds. If the artifact's provenance or status is unclear, do not bypass Gatekeeper; obtain a verified artifact or build from reviewed source following [package guidance](pkg.md).
