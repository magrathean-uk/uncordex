# Troubleshooting

Start with `uncordex status`. It shows the service, speaker, power and restore state.

## `blueutil` is missing

Install the external helper, then run `uncordex status` again:

```bash
brew install blueutil
```

Uncordex checks the Apple Silicon path `/opt/homebrew/bin/blueutil` and the Intel path `/usr/local/bin/blueutil`. `install.sh` installs it for you when Homebrew is present.

## macOS blocked Bluetooth access

Bluetooth access belongs to Uncordex itself, through the small `Uncordex.app` helper in Uncordex's data folder. The first `uncordex setup` makes macOS ask once; click Allow. If access was refused, setup opens System Settings > Privacy & Security > Bluetooth and continues once Uncordex is turned on. If setup says the helper is missing, install Apple's command line tools (`xcode-select --install`) and run the installer again.

## No dock or charger appears

Some chargers do not expose a serial, and some USB devices expose duplicate or placeholder identities. Uncordex does not infer identity from a model name, wattage, port, voltage, or battery serial. With the dock or charger attached, run:

```bash
uncordex sources
```

Use `--any-power` only when every charger may restore the speaker. Otherwise use `--disconnect-only`.

## Status says not installed or stopped

Not installed means setup has not completed. Run `uncordex setup`.

Stopped means settings exist but the service is off. Run `uncordex start`. `uncordex stop` keeps the service off across logins until you start it again. If the service is loaded but not running, run `uncordex restart` and check `uncordex logs`.

## The speaker does not restore

```bash
uncordex status
uncordex logs
```

Confirm the saved dock is attached and the Mac is on power, Bluetooth is on, and the speaker is powered, paired and in range. Restoration permission exists only if the watcher disconnected the speaker itself and verified it. A manual reconnect consumes pending permission. Automatic retries pause after 6 attempts in 5 minutes.

## A different charger appeared to restore the speaker

With a dock or charger rule (`--source`), a different charger cannot satisfy the saved identity. If the Mac stayed on power while the saved dock was connected, the dock's presence can qualify restoration. With `--any-power`, any return to power is eligible. Run `uncordex setup` again with `--source N` or `--disconnect-only` if that is too broad.

## There is no log activity

Run `uncordex status` to confirm the service is running, then `uncordex logs -f`. If an older controller is loaded, follow [migration](migration.md). Do not run both services against the same speaker.

## A brief unplug and replug was missed

Uncordex samples every 5 seconds and cannot guarantee event-level precision. A complete departure and return between samples may go unseen. Keep the source disconnected long enough for the watcher to confirm the change.

## Updating

Run the install command again. It replaces the installed files and restarts a running service, and your saved rule is kept. Run `uncordex setup` to change the speaker or rule; add `--dry-run` first to preview.
