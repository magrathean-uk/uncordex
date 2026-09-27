# Uncordex 1.0.0 Release Design

## Purpose

Rename Unplugged Speaker to Uncordex across the product, runtime namespace, documentation, repository, and release metadata. Publish the completed source-aware implementation as the canonical `v1.0.0` release on `main` without rewriting historical Git objects or touching a user's installed Bluetooth service.

## Product identity

- Product name: **Uncordex**.
- GitHub repository: `magrathean-uk/uncordex`.
- Release version: `1.0.0`; annotated Git tag: `v1.0.0`; GitHub release title: `Uncordex 1.0.0`.
- License: MIT. `LICENSE` remains the authoritative license text.
- LaunchAgent label: `uk.magrathean.uncordex.watch-power`.
- Installed namespace: `uncordex` for application, configuration, state, backup, and log paths.
- Test-boundary environment variables: `UNCORDEX_*`.
- Functional script names such as `install.sh`, `uninstall.sh`, `watch-power`, and `lib/source.sh` remain unchanged because they describe their roles rather than the old product.

The old names `Unplugged Speaker`, `unplugged-speaker`, `UNPLUGGED_*`, and `com.unplugged-speaker.watch-power` may appear only in migration or historical-release documentation and in tests that verify legacy detection.

## Runtime layout

The canonical installation uses:

| Purpose | Path or identifier |
| --- | --- |
| LaunchAgent | `~/Library/LaunchAgents/uk.magrathean.uncordex.watch-power.plist` |
| LaunchAgent label | `uk.magrathean.uncordex.watch-power` |
| Watcher | `~/.local/share/uncordex/watch-power` |
| Hardware reader | `~/.local/share/uncordex/lib/source.sh` |
| Configuration | `${XDG_CONFIG_HOME:-~/.config}/uncordex/config` |
| Runtime state | `${XDG_STATE_HOME:-~/.local/state}/uncordex/runtime-state` |
| Install backups | `${XDG_STATE_HOME:-~/.local/state}/uncordex/install-backups/` |
| Standard output | `~/Library/Logs/uncordex.log` |
| Standard error | `~/Library/Logs/uncordex-error.log` |

Temporary-file prefixes also use `uncordex-` so diagnostics contain no obsolete product branding.

## Migration and coexistence safety

Uncordex must never silently run beside a controller that can manage the same speaker.

The installer checks both legacy labels before activation:

- `com.unplugged-speaker.watch-power`, used by the prior public release.
- `com.bolyki.bt-auto-speaker-power`, used by the older local watcher.

If either service is loaded, installation stops with a specific migration message. It does not stop, overwrite, delete, or import the legacy installation automatically. The migration guide instructs the user to:

1. discover and validate the intended Uncordex source rule;
2. run an Uncordex dry run;
3. back up the exact legacy plist, application, configuration, state, and logs that exist;
4. stop only the selected legacy LaunchAgent;
5. install Uncordex;
6. verify the new label and perform physical disconnect/reconnect acceptance;
7. retain the backup until acceptance succeeds.

`uninstall.sh` stops and removes only the canonical Uncordex LaunchAgent plist. It leaves application files, configuration, state, backups, logs, and every legacy service untouched.

## Documentation

The repository contains a concise, complete operator and contributor set:

- `README.md`: product overview, safety guarantees, requirements, quick start, operating modes, and links to detailed guides.
- `docs/installation.md`: discovery, guided and noninteractive installation, dry run, updates, and installed paths.
- `docs/usage.md`: behavior, status output, logs, retry semantics, and operational limitations.
- `docs/migration.md`: exact legacy-service backup, stop, rollback, and acceptance procedure.
- `docs/troubleshooting.md`: unavailable identities, paused or exhausted restoration, Bluetooth prerequisites, and polling limitations.
- `docs/architecture.md`: component boundaries, source matching, state ownership, persistence, retries, and failure handling.
- `docs/development.md`: simulated test boundaries, commands, fixture strategy, and physical-acceptance distinction.
- `CONTRIBUTING.md`: contribution workflow, Bash 3.2 constraint, safety boundaries, and verification expectations.
- `SECURITY.md`: supported version and private reporting route under the Uncordex name.
- `CHANGELOG.md`: `1.0.0` release record.
- `LICENSE`: authoritative MIT license.
- `THIRD_PARTY_NOTICES.md`: `blueutil` attribution and its MIT license notice/source link.
- `docs/releasing.md`: version, verification, annotated-tag, GitHub-release, and metadata checklist.

Documentation uses repository-relative links and never claims simulated tests prove physical Bluetooth acceptance.

## Implementation boundaries

The rebrand changes identifiers, paths, output text, test fixtures, and documentation. It does not change the established source-selection, state-machine, retry, or Bluetooth ownership behavior except where required to recognize both legacy service labels safely.

Tests are changed before runtime scripts for each behavior-facing rename. A focused failing assertion proves the old label or namespace is still emitted; the implementation then changes minimally until the assertion passes. Documentation-only changes do not require artificial behavior tests.

The operation does not run `install.sh` or `uninstall.sh`, change a real LaunchAgent, connect or disconnect a Bluetooth device, toggle Bluetooth, or delete legacy data.

## Verification

Before publication:

1. Run Bash syntax validation for `install.sh`, `uninstall.sh`, `watch-power`, `lib/source.sh`, and `tests/run.sh`.
2. Run the complete simulated suite in `tests/run.sh`.
3. Run ShellCheck for those scripts when it is already installed.
4. Search the repository for obsolete branding and confirm every remaining match is an intentional migration or historical reference.
5. Check documentation links and version/license consistency.
6. Inspect the final diff and confirm `.serena/` and unrelated files are excluded.

Passing these checks proves only source and simulated behavior. Physical source detection and Bluetooth disconnect/restore acceptance remain unverified until a user deliberately installs Uncordex and tests real hardware.

## Git and GitHub publication

Publication is ordered to keep every public reference resolvable:

1. Commit the implementation and documentation on the release branch.
2. Update local `main` to the verified release commit without rewriting history.
3. Push `main` to the existing GitHub repository.
4. Rename the GitHub repository to `magrathean-uk/uncordex` and update the local `origin` URL.
5. Set the repository description, homepage, topics, and default branch for Uncordex.
6. Preserve the existing `v1` tag at its historical commit. Rename its GitHub release title to make its pre-Uncordex legacy status explicit; do not move or replace the tag.
7. Create and push the annotated `v1.0.0` tag at the verified `main` commit.
8. Publish GitHub release `Uncordex 1.0.0` with generated release notes corrected to match the changelog and the simulated-versus-physical evidence boundary.
9. Verify the renamed repository, default branch, tag targets, release status, license detection, and public documentation links through GitHub's read-only API.

No package registry, binary artifact, automatic update mechanism, CI workflow, telemetry, account, cloud service, pairing behavior, or Bluetooth-radio control is added.
