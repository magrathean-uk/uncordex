# Development

Run commands from the repository root on macOS. App checks require the Swift compiler and macOS SDK available through `xcrun`. Package work also uses Apple's signing and Installer tools. Read the scripts before selecting an output directory: app and package scripts replace their designated build or verification directories.

## Boundaries

Ordinary verification must not change the logged-in user's service or Bluetooth devices. Do not run `install.sh` or `uninstall.sh` directly as a test. The service suite supplies isolated paths and substitutes hardware, Bluetooth, clock, and LaunchAgent commands. The app tests use fake service adapters and local subprocess fixtures.

Keep Bash 3.2 compatibility, both Homebrew paths, and the project's single-speaker scope. Preserve unrelated work.

## Choose the checks

| Change | Relevant checks |
| --- | --- |
| Shell service, source matching, or installer | Shell syntax and `bash tests/run.sh` |
| App model, process handling, or window behavior | `bash app/test.sh`, which also runs the window tests |
| App bundle or resources | `bash app/build.sh` and inspect the generated bundle |
| Package assembly or validation | Build an artifact, then run `packaging/test.sh` with that artifact |
| UI layout | Inspect fixture screenshots at normal and minimum size, in light and dark appearance |
| Documentation | Check commands against source, links, and claims against their evidence |

Check all shell entry points without executing them:

```bash
bash -n \
  install.sh uninstall.sh watch-power lib/source.sh tests/run.sh \
  app/build.sh app/test.sh app/window-test.sh \
  packaging/build.sh packaging/validate.sh packaging/test.sh
```

For shell changes, run ShellCheck over the same files when it is already installed. Do not install it just for this check.

## App and package output

```bash
bash tests/run.sh
bash app/test.sh
bash app/build.sh
```

App output defaults to `$HOME/dev/build/uncordex/gui`. `UNCORDEX_BUILD_ROOT` can select another directory under `$HOME/dev/build`; paths with dot components or resolved escapes are rejected. A build creates a universal arm64/x86_64 app targeting macOS 13.0 and signs it ad hoc. See [App development](app.md) for the bundle and fixture interface.

```bash
bash packaging/build.sh
```

Without signing identities this produces an unsigned development package. `UNCORDEX_PKG_BUILD_ROOT` defaults to `$HOME/dev/build/uncordex/pkg`. Use the actual version from `VERSION` when selecting an artifact:

```bash
version="$(cat VERSION)"
UNCORDEX_PKG_UNDER_TEST="$HOME/dev/build/uncordex/pkg/Uncordex-$version.pkg" \
  bash packaging/test.sh
```

Set `UNCORDEX_PKG_REQUIRE_SIGNED=1` for a signed release artifact and `UNCORDEX_PKG_REQUIRE_NOTARIZED=1` when notarization is required. Without `UNCORDEX_PKG_UNDER_TEST`, the package suite checks rejection cases only. It does not validate a built package or install anything. See [Packaging](pkg.md) and [Releasing](releasing.md).

Consider [Clean Development](https://github.com/magrathean-uk/clean-development) for managing development caches and supported build output.

## Acceptance

A passing fixture suite establishes behavior under its substituted boundaries. A universal binary and deployment target establish build configuration. Neither establishes behavior on a particular Mac or speaker.

For hardware work, record the exact source and artifact, macOS version, architecture, hardware, observed state transitions, manual actions, and remaining gaps. Treat [the dated acceptance record](testing/2026-09-09-live-acceptance.md) as historical evidence for its stated implementation. Do not reuse its counts or package hash as validation of a later change.
