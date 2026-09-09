# Development and verification

## Safety boundaries

Source changes do not install Uncordex. Do not run `install.sh` or `uninstall.sh` as an ordinary source check. Do not connect or disconnect real Bluetooth hardware or load a real LaunchAgent during automated verification.

The service suite substitutes hardware snapshots, Bluetooth state, time, filesystem paths, and LaunchAgent commands. The app suite uses a fake service adapter and harmless local subprocess fixtures. The package validator expands a finished product archive under `$HOME/dev/build` and never installs it.

## Service checks

```bash
bash -n install.sh uninstall.sh watch-power lib/source.sh tests/run.sh
bash tests/run.sh
```

## Native app checks

```bash
app/test.sh
app/build.sh
```

The build output is `$HOME/dev/build/uncordex/gui/Uncordex.app`. It must contain arm64 and x86_64 slices, target macOS 13, carry the expected bundle identifier and version, contain the complete Service resources, and pass strict code-signature validation.

For deterministic visual inspection without hardware or LaunchAgent access:

```bash
"$HOME/dev/build/uncordex/gui/Uncordex.app/Contents/MacOS/Uncordex" \
  --demo \
  --screenshot "$HOME/dev/build/uncordex/gui/visual/window.png"
```

The `--demo` adapter cannot invoke service scripts, `blueutil`, `launchctl`, or physical hardware. See [native app development](app.md) for page and appearance options.

## Package checks

Build an unsigned local package with:

```bash
packaging/build.sh
```

Validate a finished signed package with:

```bash
UNCORDEX_PKG_UNDER_TEST="$HOME/dev/build/uncordex/pkg/Uncordex-1.0.0.pkg" \
UNCORDEX_PKG_REQUIRE_SIGNED=1 \
packaging/test.sh
```

Package checks inspect the expanded payload, metadata, architectures, resources, executable modes, signatures, installer choices, and absence of scripts or host metadata. They do not install the package. See [package documentation](pkg.md) for signing and notarization variables.

## ShellCheck

When ShellCheck is already installed, run it over every shell entry point:

```bash
shellcheck \
  install.sh uninstall.sh watch-power lib/source.sh tests/run.sh \
  app/build.sh app/test.sh \
  packaging/build.sh packaging/validate.sh packaging/test.sh
```

Do not install ShellCheck solely to run this command.

## Coverage and evidence

The simulated suites cover:

- exact Thunderbolt, USB hub, and adapter identity behavior;
- malformed and duplicate hardware data failing closed;
- source-aware, any-power, and disconnect-only rules;
- owned disconnect/reconnect transitions and manual user actions;
- bounded retries, restart persistence, and source loss during connection;
- read-only app status, explicit setup, service start/stop/restart, and failure states;
- process deadlines, concurrent output, and descendant cleanup;
- dry runs, staged installation, rollback, and legacy-controller blocks; and
- package structure, identifiers, resources, modes, and signatures.

A green simulated suite proves behavior under controlled boundaries. Universal slices and deployment metadata prove build configuration. Neither proves runtime behavior on a specific Mac or physical setup. Record hardware and installation acceptance separately, with observed commands, logs, state, and remaining gaps.

## Contribution style

Keep scripts compatible with macOS Bash 3.2 and both standard Homebrew paths. Add a focused regression test before changing behavior, verify that it fails for the expected reason, then make the smallest useful change. Preserve unrelated files and never edit `.serena/`.
