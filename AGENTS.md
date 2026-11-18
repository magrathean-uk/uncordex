# Uncordex project context

Uncordex is a local macOS command-line tool for an already-paired Bluetooth speaker: the `uncordex` command, the `install.sh` installer, and the `watch-power` per-user LaunchAgent watcher.

## Implementation context

- Shell entry points target macOS Bash 3.2; Homebrew paths differ between Apple Silicon and Intel Macs.
- `install.sh` and `uncordex setup`, `start`, `stop` and `uninstall` change the logged-in user's real service.
- `install.sh` can install `blueutil` through Homebrew unless `--no-install-dependencies` is given.
- Tests substitute hardware, Bluetooth, time, sleep and LaunchAgent boundaries.
- Source identity matching treats missing, duplicate, malformed or unreadable hardware data as an unsuccessful match.
- The watcher tracks whether it disconnected and verified a connection before restoring it.
- Configuration and runtime state are per-user.

## Command references

```bash
bash -n uncordex install.sh watch-power lib/source.sh tests/run.sh
bash tests/run.sh
```

ShellCheck can inspect shell entry points. Simulated checks and physical hardware behaviour are different forms of evidence.

[Contributing](.github/CONTRIBUTING.md) and [Development](docs/development.md) contain the command matrix. `docs/development/archive/` contains historical records.

## Development environment

The machine's `~/dev/machine/env.zsh` provides routed storage variables. `$TMPDIR` identifies session scratch, `$CLEAN_DEV_BUILDS` identifies throwaway build output, and cache variables identify dependency caches. `.clean-development.json` records repository build and dependency directories.
