# Contributing to Uncordex

Thanks for improving Uncordex.

## Before changing code

- Keep scripts compatible with macOS Bash 3.2.
- Preserve Apple Silicon and Intel Homebrew discovery.
- Do not add telemetry, accounts, cloud services, automatic pairing, Bluetooth-radio control, or audio-output switching.
- Do not run the installer or uninstaller as an ordinary source check.
- Do not operate real Bluetooth devices or real LaunchAgents in automated tests.
- Preserve unrelated work and never edit `.serena/`.

## Tests

Write a focused regression test before changing behavior. Run:

```bash
bash -n \
  install.sh uninstall.sh watch-power lib/source.sh tests/run.sh \
  app/build.sh app/test.sh \
  packaging/build.sh packaging/validate.sh packaging/test.sh
bash tests/run.sh
bash app/test.sh
```

Run ShellCheck when it is already available:

```bash
shellcheck \
  install.sh uninstall.sh watch-power lib/source.sh tests/run.sh \
  app/build.sh app/test.sh \
  packaging/build.sh packaging/validate.sh packaging/test.sh
```

For package changes, validate a finished artifact with `packaging/test.sh`; package validation does not install it. Report simulated verification, package inspection, and physical hardware acceptance separately.

## Changes and pull requests

Keep changes small and explain user-visible behavior, test coverage, and hardware limits. Do not claim that fixture-based checks prove real dock, charger, or Bluetooth-speaker behavior. Do not include user configuration, runtime state, logs, device addresses, source keys, or credentials.
