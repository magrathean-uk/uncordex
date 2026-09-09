# Migration from Older Watchers

Uncordex intentionally refuses to install while either known older speaker controller is loaded:

- `com.unplugged-speaker.watch-power`, the prior public Unplugged Speaker release;
- `com.bolyki.bt-auto-speaker-power`, an older local watcher.

This prevents two services from disconnecting or reconnecting the same speaker. The installer does not stop, overwrite, delete, or import an older installation automatically.

## 1. Validate Uncordex first

Connect the intended dock or charger and run discovery:

```bash
./install.sh --discover
./install.sh AA-BB-CC-DD-EE-FF --source SOURCE_KEY --dry-run
```

If macOS cannot provide a unique source identity, make an explicit choice between `--any-power` and `--disconnect-only`.

## 2. Preserve the old installation

Create a dated backup outside the old application directories. Back up only paths that exist on the Mac:

```bash
backup_dir="$HOME/.local/state/uncordex/migration-backups/legacy-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir/logs"
```

For the prior public release, preserve its LaunchAgent, application directory, configuration, and logs:

```bash
cp -p "$HOME/Library/LaunchAgents/com.unplugged-speaker.watch-power.plist" "$backup_dir/" 2>/dev/null || true
cp -pR "$HOME/.local/share/unplugged-speaker" "$backup_dir/" 2>/dev/null || true
cp -pR "$HOME/.config/unplugged-speaker" "$backup_dir/" 2>/dev/null || true
cp -p "$HOME/Library/Logs/unplugged-speaker.log" "$HOME/Library/Logs/unplugged-speaker-error.log" "$backup_dir/logs/" 2>/dev/null || true
```

For the older local watcher, preserve its paths if present:

```bash
cp -p "$HOME/Library/LaunchAgents/com.bolyki.bt-auto-speaker-power.plist" "$backup_dir/" 2>/dev/null || true
cp -pR "$HOME/Library/Application Scripts/bt-auto-speaker-power" "$backup_dir/" 2>/dev/null || true
cp -pR "$HOME/Library/Application Support/bt-auto-speaker-power" "$backup_dir/" 2>/dev/null || true
cp -p "$HOME/Library/Logs/bt-auto-speaker-power/out.log" "$HOME/Library/Logs/bt-auto-speaker-power/err.log" "$backup_dir/logs/" 2>/dev/null || true
```

## 3. Stop exactly one legacy service

After verifying the backup, stop only the label that is actually loaded:

```bash
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.unplugged-speaker.watch-power.plist"
```

or:

```bash
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.bolyki.bt-auto-speaker-power.plist"
```

Do not delete the backup or old files yet.

## 4. Install and accept Uncordex

With the native app, open **Speaker & Rule**, select the speaker and saved source, review **Preview**, then select **Save & Start**. With a source checkout, run:

```bash
./install.sh AA-BB-CC-DD-EE-FF --source SOURCE_KEY
launchctl print "gui/$(id -u)/uk.magrathean.uncordex.watch-power"
```

Confirm that the legacy label remains unloaded. Its property list can start it again at a future login unless you deliberately disable or remove that legacy installation.

Perform a deliberate physical disconnect and restoration check with the actual dock or charger and speaker. The simulated suite cannot establish this acceptance.

If installation fails before activation, restart the preserved legacy service using its backed-up plist:

```bash
launchctl bootstrap "gui/$(id -u)" "$backup_dir/com.unplugged-speaker.watch-power.plist"
```

Adjust the filename if the backup came from the other legacy controller. Keep all legacy data until physical acceptance succeeds.
