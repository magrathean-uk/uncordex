# Unplugged Speaker

A small per-user macOS service that disconnects one Bluetooth speaker when the Mac switches to battery power and reconnects it when AC power returns.

It uses [`blueutil`](https://github.com/toy/blueutil) for Bluetooth control and a `launchd` agent for automatic startup after login. No daemon, cloud service, account, or telemetry is involved.

## Behaviour

- Polls the macOS power source every five seconds.
- Disconnects the configured speaker on the transition to battery power.
- Reconnects it on the transition to AC power.
- Retries reconnection up to three times, five seconds apart.
- Stores only the speaker address, resolved `blueutil` path, and last observed power source.

## Requirements

- macOS.
- Homebrew.
- A Bluetooth speaker that is already paired with the Mac.
- A per-user login session; the service is not a system daemon.

Both Apple Silicon (`/opt/homebrew`) and Intel (`/usr/local`) Homebrew installations are supported.

## Install

```bash
brew install blueutil
git clone https://github.com/magrathean-uk/unplugged-speaker.git
cd unplugged-speaker
blueutil --paired
./install.sh AA-BB-CC-DD-EE-FF
```

Replace `AA-BB-CC-DD-EE-FF` with the paired speaker's Bluetooth address. Colons or hyphens are accepted.

The installer validates the address, resolves the installed `blueutil` binary, writes the local configuration, installs the watcher, validates the generated property list, and starts the LaunchAgent.

Re-running `install.sh` updates the configured speaker and installed watcher.

## Verify

Check the service:

```bash
launchctl print "gui/$(id -u)/com.unplugged-speaker.watch-power"
```

Follow its logs:

```bash
tail -f ~/Library/Logs/unplugged-speaker.log
tail -f ~/Library/Logs/unplugged-speaker-error.log
```

Test the Bluetooth address directly:

```bash
blueutil --is-connected AA-BB-CC-DD-EE-FF
blueutil --disconnect AA-BB-CC-DD-EE-FF
blueutil --connect AA-BB-CC-DD-EE-FF
```

## Installed files

| Purpose | Path |
| --- | --- |
| LaunchAgent | `~/Library/LaunchAgents/com.unplugged-speaker.watch-power.plist` |
| Watcher | `~/.local/share/unplugged-speaker/watch-power` |
| Configuration | `${XDG_CONFIG_HOME:-~/.config}/unplugged-speaker/config` |
| Last power state | `${XDG_STATE_HOME:-~/.local/state}/unplugged-speaker/last-power` |
| Standard output | `~/Library/Logs/unplugged-speaker.log` |
| Standard error | `~/Library/Logs/unplugged-speaker-error.log` |

The installer records the exact `blueutil` path in the configuration. Set `BLUEUTIL=/absolute/path/to/blueutil` there only when overriding it intentionally.

## Remove

```bash
./uninstall.sh
```

That stops the service and removes the LaunchAgent. It deliberately leaves the copied watcher, configuration, state, and logs in place.

To purge those as well:

```bash
rm -rf ~/.local/share/unplugged-speaker
rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/unplugged-speaker"
rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/unplugged-speaker"
rm -f ~/Library/Logs/unplugged-speaker.log
rm -f ~/Library/Logs/unplugged-speaker-error.log
```

## Troubleshooting

If reconnection fails, first confirm the speaker is powered on, in range, paired, and manually connectable with `blueutil`. Then inspect the error log and the stored `BLUEUTIL` path.

If the service is not loaded, run the installer again rather than hand-editing the property list. The installer performs `plutil` validation and replaces the existing per-user service safely.

This project reacts to AC/battery source changes. It is not a general Bluetooth reliability manager and does not attempt to manage sleep, wake, audio routing, multiple speakers, or competing connections from other devices.

## Development check

```bash
bash -n install.sh uninstall.sh watch-power
```

## Security and licence

Report security issues through [`SECURITY.md`](./SECURITY.md). The code is licensed under the [MIT Licence](./LICENSE). Third-party notices are recorded in [`license.md`](./license.md).
