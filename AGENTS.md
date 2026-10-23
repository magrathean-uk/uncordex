# Uncordex project context

Uncordex is a local macOS app and per-user LaunchAgent for an already-paired Bluetooth speaker. The app, source scripts and packaged service are related delivery forms.

## Implementation context

- Shell entry points target macOS Bash 3.2; Homebrew paths differ between Apple Silicon and Intel Macs.
- `install.sh` and `uninstall.sh` change the logged-in user's real service.
- Source setup can install `blueutil` through Homebrew. The app uses `--no-install-dependencies`; the package does not install Homebrew packages.
- Tests substitute hardware, Bluetooth, time, sleep and LaunchAgent boundaries.
- Source identity matching treats missing, duplicate, malformed or unreadable hardware data as an unsuccessful match.
- The watcher tracks whether it disconnected and verified a connection before restoring it.
- Configuration and runtime state are per-user.

## Command references

Core service checks:

```bash
bash -n install.sh uninstall.sh watch-power lib/source.sh tests/run.sh
bash tests/run.sh
```

`bash app/test.sh` covers the app. `packaging/test.sh` inspects the finished package. ShellCheck can inspect shell entry points. Simulated checks, package inspection and physical hardware behaviour are different forms of evidence.

[Contributing](.github/CONTRIBUTING.md) and [Development](docs/development.md) contain the command matrix and delivery documentation. `docs/development/archive/` contains historical records.

## Development environment

The machine's `~/dev/machine/env.zsh` provides routed storage variables. `$TMPDIR` identifies session scratch, `$CLEAN_DEV_BUILDS` identifies throwaway build output, and cache variables identify dependency caches. `.clean-development.json` records repository build and dependency directories.
