# Development

## Boundaries

Source changes do not install Uncordex. Do not run `install.sh` or `uninstall.sh` as an ordinary test, and do not connect or disconnect real Bluetooth hardware while verifying source changes.

The test harness substitutes fixture hardware snapshots, Bluetooth state, time, and LaunchAgent commands. It exercises the actual installer and watcher decisions with temporary paths under a test directory.

## Required checks

```bash
bash -n install.sh uninstall.sh watch-power lib/source.sh tests/run.sh
bash tests/run.sh
```

Run ShellCheck when it is already installed:

```bash
shellcheck install.sh uninstall.sh watch-power lib/source.sh tests/run.sh
```

Do not install ShellCheck only to run this command.

## Test coverage

The suite covers:

- exact Thunderbolt, USB hub, and adapter identity behavior;
- malformed and duplicate hardware data failing closed;
- source-aware, any-power, and disconnect-only modes;
- owned disconnect/reconnect transitions and manual user actions;
- bounded retries, restart persistence, and source loss during connection;
- dry runs, staged installation, rollback, and both legacy-controller blocks.

A green simulated suite proves code behavior under controlled fixtures. It does not prove hardware discovery or Bluetooth restoration on a particular Mac, dock, charger, or speaker.

## Style

Use Bash 3.2 syntax. Keep Apple Silicon and Intel Homebrew paths. Add a focused test before modifying behavior, verify it fails for the expected reason, then implement the smallest change that makes it pass. Preserve unrelated files and never edit `.serena/`.
