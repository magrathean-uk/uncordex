# Development

Run commands from the repository root on macOS.

## Boundaries

Ordinary verification must not change the logged-in user's service or Bluetooth devices. Do not run `install.sh` or `uncordex setup`, `start`, `stop` or `uninstall` directly as a test. The service suite supplies isolated paths and substitutes hardware, Bluetooth, clock, and LaunchAgent commands.

Keep Bash 3.2 compatibility, both Homebrew paths, and the project's single-speaker scope. Preserve unrelated work.

## Checks

Check all shell entry points without executing them:

```bash
bash -n uncordex install.sh watch-power lib/source.sh tests/run.sh
```

Run the test suite:

```bash
bash tests/run.sh
```

When ShellCheck is already installed, run it over the same files. Do not install it just for this check. For documentation changes, check commands against `uncordex` usage text, links, and claims against their evidence.

Run build and test commands through [Clean Development](https://github.com/magrathean-uk/clean-development), as the "Clean development" section of [AGENTS.md](../AGENTS.md) requires. It routes development caches and supported build output; do not unset or bypass the routed environment variables.

## Acceptance

A passing fixture suite establishes behaviour under its substituted boundaries. It does not establish behaviour on a particular Mac or speaker.

For hardware work, record the exact source, macOS version, architecture, hardware, observed state transitions, manual actions, and remaining gaps. Treat [the dated acceptance record](testing/2026-09-09-live-acceptance.md) as historical evidence for its stated implementation. Do not reuse its counts as validation of a later change.
