# Migration from older watchers

`uncordex setup` refuses to continue while either known older speaker controller is loaded:

- `com.unplugged-speaker.watch-power`, used by the earlier Unplugged Speaker release;
- `com.bolyki.bt-auto-speaker-power`, used by an older local watcher.

This prevents two services from controlling the same speaker. Setup does not stop, overwrite, delete, or import an older installation automatically.

## 1. Validate Uncordex

Connect the intended dock or charger, then look at what Uncordex can see and preview a setup:

```bash
uncordex devices
uncordex sources
uncordex setup 1 --source 1 --dry-run
```

If macOS cannot provide a unique source identity, choose `--any-power` or `--disconnect-only` deliberately.

## 2. Back up the old installation

Create a dated backup outside the old application directories. Run this block in one shell; it stops on a failed copy and skips paths that do not exist. Configuration honors `XDG_CONFIG_HOME` when set. If the old watcher uses custom paths, include those too.

```bash
backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/uncordex/migration-backups/legacy-$(date +%Y%m%d-%H%M%S)"
(
  set -e
  mkdir -p "$backup_dir"
  for path in \
    "$HOME/Library/LaunchAgents/com.unplugged-speaker.watch-power.plist" \
    "$HOME/.local/share/unplugged-speaker" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/unplugged-speaker" \
    "$HOME/Library/Logs/unplugged-speaker.log" \
    "$HOME/Library/Logs/unplugged-speaker-error.log" \
    "$HOME/Library/LaunchAgents/com.bolyki.bt-auto-speaker-power.plist" \
    "$HOME/Library/Application Scripts/bt-auto-speaker-power" \
    "$HOME/Library/Application Support/bt-auto-speaker-power" \
    "$HOME/Library/Logs/bt-auto-speaker-power"; do
    if [ -e "$path" ]; then
      relative_path="${path#/}"
      mkdir -p "$backup_dir/$(dirname "$relative_path")"
      cp -pR "$path" "$backup_dir/$relative_path"
    fi
  done
)
```

Continue only if the block succeeds. Inspect the backup before stopping a service. It preserves the original path structure beneath the backup directory, so application data and configuration directories with the same name do not collide.

## 3. Stop only the loaded legacy service

After checking the backup, stop the label that is actually loaded:

```bash
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.unplugged-speaker.watch-power.plist"
```

or:

```bash
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.bolyki.bt-auto-speaker-power.plist"
```

Do not delete the backup or old files yet. The old property list may load the service again at a later login unless you deliberately disable or remove that installation.

## 4. Set up and accept Uncordex

Run guided setup, then inspect the service:

```bash
uncordex setup
uncordex status
```

Confirm the old label remains unloaded. Test a physical disconnect and restoration with the actual dock or charger and speaker. Fixture-based tests cannot establish this acceptance.

If setup fails, first confirm Uncordex is not running. Stop its canonical service if necessary, then bootstrap only the preserved legacy service whose backup you checked:

```bash
if launchctl print "gui/$(id -u)/uk.magrathean.uncordex.watch-power" >/dev/null 2>&1; then
  echo "Stop Uncordex before restoring the legacy service." >&2
else
  launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.unplugged-speaker.watch-power.plist"
fi
```

Adjust the filename for the legacy controller you backed up. If the original plist was removed, restore it from its corresponding path inside the backup before bootstrapping it. Keep all legacy data until physical acceptance succeeds.
