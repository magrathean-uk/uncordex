# Unplugged Speaker

Tiny macOS helper for Bluetooth speakers.

Unplug Mac: speaker disconnects.  
Plug Mac back: speaker reconnects.

It watches macOS power state every five seconds and uses [blueutil](https://github.com/toy/blueutil) for Bluetooth control.

## Install

```bash
brew install blueutil
git clone https://github.com/YOUR-USERNAME/unplugged-speaker.git
cd unplugged-speaker
./install.sh AA-BB-CC-DD-EE-FF
```

Use your speaker Bluetooth MAC address. Find it with:

```bash
blueutil --paired
```

The installer creates a per-user `launchd` service, so it starts again after login.

## Remove

```bash
./uninstall.sh
```

This stops the service. Config and app files stay at `~/.config/unplugged-speaker` and `~/.local/share/unplugged-speaker`.

## Notes

- macOS only.
- Needs Homebrew and `blueutil`.
- Reconnection is retried three times after plugging in.

## License

MIT
