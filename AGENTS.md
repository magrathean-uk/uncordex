# Uncordex development guidance

## Project boundaries

- Uncordex is a local macOS app and per-user LaunchAgent for one already-paired Bluetooth speaker. Keep the app, source scripts, and packaged service behavior aligned.
- Preserve unrelated and untracked work.
- Keep shell scripts compatible with macOS Bash 3.2 and both Apple Silicon and Intel Homebrew paths.
- Do not add telemetry, accounts, cloud services, automatic Bluetooth pairing, Bluetooth-radio control, audio-output switching, or a privileged daemon.

## Safe development

- `install.sh` and `uninstall.sh` change the logged-in user's real service. Do not run either as an ordinary source check.
- Source setup can ask Homebrew to install `blueutil`. The app uses `--no-install-dependencies`, and the package does not install Homebrew packages. Keep this distinction explicit in product and security documentation.
- Automated checks must not operate real Bluetooth devices or a real LaunchAgent. Use the existing substituted hardware, Bluetooth, time, sleep, and LaunchAgent boundaries.
- Keep source identity matching fail-closed. Missing, duplicate, malformed, or unreadable hardware data must not become a broad match.
- Preserve the watcher ownership rule: it may restore only a connection it previously disconnected and verified.
- Keep configuration and runtime state private to the current user. Do not expose device addresses, source keys, logs, credentials, or user paths in fixtures, documentation, or pull requests.

## Validation

For behavior changes, run the smallest relevant checks first. The core service checks are:

```bash
bash -n install.sh uninstall.sh watch-power lib/source.sh tests/run.sh
bash tests/run.sh
```

For app changes, run `bash app/test.sh`. For package changes, validate the finished artifact with `packaging/test.sh`. Run ShellCheck over changed shell entry points only when it is already installed. Report simulated checks, package inspection, and physical hardware acceptance separately.

## Delivery

Keep changes small and focused. Historical records in `docs/development/archive/` are not current task gates. Within existing authorization, continue safe, reversible local work without a fresh approval. Installation, signing, notarization, publishing, tags, releases, and live-service changes require authorization for that action. See `.github/CONTRIBUTING.md` and `docs/development.md` for the full command matrix and evidence boundary.
- Legal files (`LICENSE`, `NOTICE`, `docs/legal/`, contributor terms, copyright and attribution strings) are owner-controlled: change them only on the owner's explicit instruction.
