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

<!-- clean-development-policy:v2 (canonical text: ~/dev/source/dev-bootstrap/snippets/clean-development-policy.md) -->
## Clean development (mandatory)

This project follows [Clean Development](https://github.com/magrathean-uk/clean-development) and the machine rule that nothing creates tool state under `~` (only the allow-listed agent homes).

- Load `~/dev/machine/env.zsh`; `~/.zshenv` does this for every zsh. Machine storage preferences live in `~/dev/machine/storage.conf`; workspace navigation is in `~/dev/START-HERE.md`.
- New sessions select `/Volumes/4TB/machine/cache` when the configured volume is actually mounted and writable, otherwise `~/dev/machine/cache` for ordinary smaller work. Use routed `DEVCACHE`, `CLEAN_DEVELOPMENT_{ROOT,CACHE_ROOT,BUILD_ROOT,SCRATCH_ROOT}`, `BOLYKI_DEV_LIBS` and `TMPDIR`; builds and scratch are beneath the selected cache. Keep active-session destinations fixed; stop if required storage disappears. Other users configure their own volume and fallback.
- SpecieX, large video/model jobs and VMs require external storage; never use internal fallback. Persistent labs, credentials, installed toolchains, source and final deliverables are not disposable caches.
- All active Git entry points belong under `~/dev/source/`, third-party repositories in `source/third-party/`, websites in `source/magrathean/`, and Teslatlas products/docs in `source/teslatlas-service/`. Do not read, scan, move or edit `~/dev/porn`.
- Preserve routed tool homes/caches, caller overrides and SDK/toolchain choices. Never unset or bypass routing. Scrubbed environments must restore the reviewed routing before cache-writing tools run; preserve intentional hermetic Git/Cargo isolation.
- Run builds, tests, installs and anything else that writes caches or build output through Clean Development: `clean-development run --session session-only -- <command>`. Follow its docs and keep its receipts.
- Do not add installers or scripts that default into `~` (`~/.cargo`, `~/.rustup`, `~/.cache`, `~/.npm`, `~/.swiftpm`, `~/.gradle`, ...) and do not hardcode `$HOME` paths for caches; use the routed variables.
- Before finishing, run `dev-env-check`, `dev-projects-check` and `dev-audit`; require passing environment/project checks and no new home-audit entries compared with the task baseline. Fix violations your work caused.

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
