# Uncordex 1.0.0 Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish the source-aware macOS Bluetooth speaker controller as Uncordex 1.0.0, with a clean runtime namespace, safe legacy detection, complete documentation, and verified GitHub release metadata.

**Architecture:** Retain the tested source-aware watcher behavior while replacing every canonical product identifier at its external boundary. The installer owns the new `uk.magrathean.uncordex.watch-power` service and blocks either historic controller before writing; the watcher owns the new configuration/state paths. Documentation describes the new installation and an explicit manual migration rather than automatic data or service changes.

**Tech Stack:** macOS Bash 3.2, `launchctl`, `plutil`, `ioreg`, `blueutil`, shell test harness, Git, GitHub CLI.

**Spec:** `docs/superpowers/specs/2026-09-09-uncordex-release-design.md`

## Global Constraints

- Keep Bash compatible with macOS Bash 3.2 and both Apple Silicon and Intel Homebrew locations.
- Do not run `install.sh` or `uninstall.sh` outside the simulated harness.
- Do not connect, disconnect, pair, or otherwise operate real Bluetooth hardware.
- Canonical service label: `uk.magrathean.uncordex.watch-power`.
- Canonical namespaces and test-boundary variables use `uncordex` and `UNCORDEX_*`.
- Detect `com.unplugged-speaker.watch-power` and `com.bolyki.bt-auto-speaker-power` before persistent installation writes.
- Retain MIT licensing and create no telemetry, accounts, cloud services, CI, package publication, or binary artifacts.
- Preserve `.serena/` and unrelated working-tree content.
- Report simulated verification separately from real physical-hardware acceptance.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `tests/run.sh` | Isolated contract tests for canonical naming, legacy blocking, staged installation, and watcher behavior. |
| `install.sh` | New service installation, namespace defaults, legacy detection, staged activation, and rollback. |
| `uninstall.sh` | Canonical Uncordex-service removal only. |
| `watch-power` | New configuration/state defaults and test seam names; state-machine behavior unchanged. |
| `lib/source.sh` | New branding in the hardware-reader comment and temporary snapshot prefix. |
| `README.md` | Product overview and concise operator entry point. |
| `docs/*.md` | Detailed installation, usage, migration, troubleshooting, architecture, development, and releasing guidance. |
| `CONTRIBUTING.md`, `SECURITY.md`, `THIRD_PARTY_NOTICES.md` | Community, security, and licensing documentation. |
| `CHANGELOG.md`, `VERSION` | Release identity and user-visible change record. |

### Task 1: Lock down the Uncordex installer contract

**Files:**
- Modify: `tests/run.sh:410-592`
- Test: `tests/run.sh`

**Interfaces:**
- Consumes: the executable `install.sh` via `run_installer`.
- Produces: `UNCORDEX_APP_DIR`, `UNCORDEX_CONFIG_DIR`, `UNCORDEX_STATE_DIR`, `UNCORDEX_PLIST`, `UNCORDEX_LOG_DIR`, `UNCORDEX_BLUEUTIL`, `UNCORDEX_LAUNCHCTL`, and `UNCORDEX_LAUNCH_TRACE`.
- Requires: output `Installed uk.magrathean.uncordex.watch-power.` after a successful simulated installation.

- [ ] **Step 1: Replace the successful-install assertion with the intended new label.**

```bash
assert_contains "Installed uk.magrathean.uncordex.watch-power" "$success_output" \
  "successful installation reports the canonical service"
```

- [ ] **Step 2: Run the suite and verify the assertion fails because `install.sh` still emits the old label.**

Run: `bash tests/run.sh`

Expected: one failed assertion for the canonical-service output; existing watcher coverage continues to run in the isolated harness.

- [ ] **Step 3: Make the fake LaunchAgent boundary distinguish both legacy labels and the new canonical label.**

```bash
case "${2:-}" in
  *com.unplugged-speaker.watch-power|*com.bolyki.bt-auto-speaker-power)
    [ "${UNCORDEX_LEGACY_SERVICE_PRESENT:-0}" = 1 ] && exit 0 ;;
  *uk.magrathean.uncordex.watch-power)
    [ "${UNCORDEX_CANONICAL_LOADED:-0}" = 1 ] && exit 0 ;;
esac
```

- [ ] **Step 4: Rename all simulated installer seams to `UNCORDEX_*` and add separate cases for both historic services.**

```bash
UNCORDEX_LEGACY_SERVICE_PRESENT=1
legacy_output="$(run_installer legacy-unplugged AA-BB-CC-DD-EE-FF --any-power 2>&1)"
assert_contains "com.unplugged-speaker.watch-power" "$legacy_output" "prior public watcher identifies itself"

UNCORDEX_LEGACY_SERVICE_PRESENT=1
legacy_output="$(run_installer legacy-bt-auto AA-BB-CC-DD-EE-FF --any-power 2>&1)"
assert_contains "com.bolyki.bt-auto-speaker-power" "$legacy_output" "older watcher identifies itself"
```

Keep all inputs inside `$TEST_ROOT`; do not call a real `launchctl` or write a real LaunchAgent.

- [ ] **Step 5: Run the suite and verify it still fails only at the new-label assertion.**

Run: `bash tests/run.sh`

Expected: the newly named assertion fails because production code has not yet changed; no test invokes real Bluetooth or LaunchAgent boundaries.

- [ ] **Step 6: Commit the red test contract.**

```bash
git add tests/run.sh
git commit -m "test: define Uncordex installer contract"
```

### Task 2: Rebrand the runtime namespace while preserving behavior

**Files:**
- Modify: `install.sh:2-344`
- Modify: `uninstall.sh:1-7`
- Modify: `watch-power:1-540`
- Modify: `lib/source.sh:1-230`
- Test: `tests/run.sh`

**Interfaces:**
- Consumes: Task 1 `UNCORDEX_*` seams and the two immutable legacy-label literals.
- Produces: a new label, plist name, paths, log names, temporary-file prefixes, and status defaults in the Uncordex namespace.

- [ ] **Step 1: Change installer defaults and injected seams to their canonical values.**

```bash
APP_DIR="${UNCORDEX_APP_DIR:-$HOME/.local/share/uncordex}"
CONFIG_DIR="${UNCORDEX_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/uncordex}"
STATE_DIR="${UNCORDEX_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/uncordex}"
PLIST="${UNCORDEX_PLIST:-$HOME/Library/LaunchAgents/uk.magrathean.uncordex.watch-power.plist}"
LABEL="uk.magrathean.uncordex.watch-power"
```

Rename all remaining installer seams (`FORCE_INTERACTIVE`, `BLUEUTIL`, `BREW`, `LAUNCHCTL`, and `PLUTIL`) from `UNPLUGGED_*` to `UNCORDEX_*`, and change staged logs to `uncordex.log` and `uncordex-error.log`.

- [ ] **Step 2: Replace the singular old-service check with a loop that reports the actual detected legacy label.**

```bash
for legacy_label in com.unplugged-speaker.watch-power com.bolyki.bt-auto-speaker-power; do
  if "$LAUNCHCTL" print "gui/$USER_ID/$legacy_label" >/dev/null 2>&1; then
    /usr/bin/printf '%s\n' "A legacy speaker watcher ($legacy_label) is running." \
      "Installation stopped to prevent two services controlling the speaker." \
      "Review and stop that exact service before performing a controlled migration." >&2
    exit 1
  fi
done
```

Run this check after staging validation and before any persistent path is created, exactly as the current old-service check does.

- [ ] **Step 3: Update uninstall defaults, watcher state/config defaults, source-library comments, and temporary-file prefixes.**

```bash
CONFIG_FILE="${UNCORDEX_CONFIG_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/uncordex/config}"
STATE_DIR="${UNCORDEX_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/uncordex}"
```

Use `uncordex-watch.XXXXXX`, `uncordex-install.XXXXXX`, and `uncordex-source.XXXXXX` prefixes. Keep state schema, configuration keys, source matching, retry scheduling, and Bluetooth command behavior untouched.

- [ ] **Step 4: Run the full simulated suite and verify green.**

Run: `bash tests/run.sh`

Expected: exit 0 with no failed assertions, including canonical-label success, both legacy-label blocks, and rollback coverage.

- [ ] **Step 5: Run syntax validation and ShellCheck when available.**

Run: `bash -n install.sh uninstall.sh watch-power lib/source.sh tests/run.sh`

Run: `command -v shellcheck >/dev/null && shellcheck install.sh uninstall.sh watch-power lib/source.sh tests/run.sh || true`

Expected: syntax validation exits 0; record whether ShellCheck was available instead of treating absence as a pass.

- [ ] **Step 6: Commit the green rebrand.**

```bash
git add install.sh uninstall.sh watch-power lib/source.sh tests/run.sh
git commit -m "feat: rename runtime to Uncordex"
```

### Task 3: Publish operator, contributor, and legal documentation

**Files:**
- Modify: `README.md`, `SECURITY.md`, `CHANGELOG.md`, `VERSION`
- Rename: `license.md` to `THIRD_PARTY_NOTICES.md`
- Create: `CONTRIBUTING.md`, `docs/installation.md`, `docs/usage.md`, `docs/migration.md`, `docs/troubleshooting.md`, `docs/architecture.md`, `docs/development.md`, `docs/releasing.md`
- Test: repository-relative link checker and obsolete-brand search

**Interfaces:**
- Consumes: exact runtime layout from Task 2 and the MIT decision from the design spec.
- Produces: a linked documentation set that names Uncordex consistently and isolates historical references to migration and release-history material.

- [ ] **Step 1: Write an initially failing documentation-contract check.**

Run: `rg -n "Unplugged Speaker|unplugged-speaker|UNPLUGGED_|com\\.unplugged-speaker" README.md SECURITY.md install.sh uninstall.sh watch-power lib/source.sh`

Expected: matches, proving the canonical code and top-level documentation still expose old branding before this task’s edits.

- [ ] **Step 2: Write the top-level and detailed documentation.**

Include every document specified in the design. Use the canonical service label and paths verbatim. Put every intentional old-name reference in `docs/migration.md` or a historical-release note, and explain its purpose adjacent to the reference. State in `README.md`, `docs/development.md`, and `docs/releasing.md` that simulated tests are not physical Bluetooth acceptance.

- [ ] **Step 3: Replace `license.md` with `THIRD_PARTY_NOTICES.md` and retain MIT as the project license.**

```markdown
# Third-Party Notices

Uncordex is licensed under the [MIT License](./LICENSE).

| Tool | License | Source |
| --- | --- | --- |
| `blueutil` | MIT | https://github.com/toy/blueutil |
```

Do not modify the MIT license text in `LICENSE`.

- [ ] **Step 4: Verify documentation links, version consistency, and old-name scope.**

Run: `rg -o '\\]\\([^)]*\\.md[^)]*\\)' README.md CONTRIBUTING.md SECURITY.md docs/*.md | sort -u`

For each local Markdown target, confirm the target exists. Then run: `rg -n "Unplugged Speaker|unplugged-speaker|UNPLUGGED_|com\\.unplugged-speaker" --glob '!docs/migration.md' --glob '!docs/superpowers/**' --glob '!tests/run.sh' .`

Expected: no unintentional canonical old-brand references; the two legacy label literals remain only in installer/test migration logic and the migration guide.

- [ ] **Step 5: Commit documentation and release identity.**

```bash
git add README.md SECURITY.md CHANGELOG.md VERSION CONTRIBUTING.md THIRD_PARTY_NOTICES.md docs
git rm license.md
git commit -m "docs: publish Uncordex operator guide"
```

### Task 4: Verify, publish main, rename GitHub, and release 1.0.0

**Files:**
- Verify: all tracked implementation and documentation files
- Remote state: `magrathean-uk/unplugged-speaker` becoming `magrathean-uk/uncordex`

**Interfaces:**
- Consumes: verified release commit from Tasks 1-3.
- Produces: updated `main`, renamed GitHub repository, immutable historic `v1`, annotated `v1.0.0`, and published release `Uncordex 1.0.0`.

- [ ] **Step 1: Run final source verification from a clean intended index.**

```bash
bash -n install.sh uninstall.sh watch-power lib/source.sh tests/run.sh
bash tests/run.sh
command -v shellcheck >/dev/null && shellcheck install.sh uninstall.sh watch-power lib/source.sh tests/run.sh || true
git diff --check main...HEAD
git status --short
```

Expected: syntax and suite exit 0; report ShellCheck availability; the only working-tree change must be a pre-existing, excluded `.serena/` directory.

- [ ] **Step 2: Inspect ancestry and fast-forward `main` to the verified release commit.**

```bash
git fetch origin main --tags
git merge-base --is-ancestor origin/main HEAD
git branch -f main HEAD
git push origin main:main
```

Expected: ancestry check exits 0. Do not force-push and stop if remote `main` has advanced incompatibly.

- [ ] **Step 3: Rename repository and refresh GitHub metadata.**

```bash
gh repo rename uncordex --repo magrathean-uk/unplugged-speaker --yes
git remote set-url origin https://github.com/magrathean-uk/uncordex.git
gh repo edit magrathean-uk/uncordex --description "A source-aware macOS Bluetooth speaker power watcher." --homepage "" --add-topic macos,bluetooth,launchagent,blueutil,open-source
```

Keep `main` as default. Do not enable Actions, packages, or release artifacts beyond the requested GitHub release.

- [ ] **Step 4: Preserve historical `v1`, update its release title, then create the annotated release.**

```bash
gh release edit v1 --repo magrathean-uk/uncordex --title "Unplugged Speaker v1 (legacy, pre-Uncordex)"
git tag -a v1.0.0 -m "Uncordex 1.0.0"
git push origin v1.0.0
gh release create v1.0.0 --repo magrathean-uk/uncordex --title "Uncordex 1.0.0" --notes-file RELEASE_NOTES.md
```

Create `RELEASE_NOTES.md` temporarily from the `1.0.0` changelog section. It must explicitly say automated tests are simulated and physical Bluetooth acceptance remains outstanding. Delete the temporary file after release creation; do not upload binaries or source archives manually.

- [ ] **Step 5: Verify GitHub state read-only.**

```bash
gh repo view magrathean-uk/uncordex --json name,nameWithOwner,defaultBranchRef,description,homepageUrl,licenseInfo,url
gh api repos/magrathean-uk/uncordex/git/ref/tags/v1
gh api repos/magrathean-uk/uncordex/git/ref/tags/v1.0.0
gh release view v1 --repo magrathean-uk/uncordex --json name,tagName,isDraft,isPrerelease,url
gh release view v1.0.0 --repo magrathean-uk/uncordex --json name,tagName,isDraft,isPrerelease,url
git ls-remote --heads --tags origin
```

Expected: repository name is `uncordex`; default branch is `main`; MIT is detected; `v1` retains its historical target; `v1.0.0` resolves to verified `main`; both releases are published; and `origin` points to the renamed repository.

- [ ] **Step 6: Record publication only if source files changed.**

```bash
git status --short
git log --oneline origin/main..HEAD
```

Expected: no uncommitted product files. Do not create an empty commit.
