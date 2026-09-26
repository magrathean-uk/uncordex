# Changelog

Entries describe repository development. Consult the matching tag and release assets before treating an entry as a distributed app or package.

## Unreleased

- Require fresh source confirmation after unreadable observations and retain the reconnect budget when readings become unknown during an attempt.
- Preserve running-service files when the installer or uninstaller cannot stop the LaunchAgent; reject repeated or conflicting setup options.
- Preserve speaker selections across reordered discovery and retain both prior lists when discovery fails.
- Wait for active app operations before quitting, and expand preview/error feedback so it remains readable at the minimum window size.
- Guard package-validation cleanup paths and support validation of unsigned development packages without weakening required-signature checks.
- Add simulated service and AppKit regression coverage, validate app version input, and correct the installation guide's discovery button label.

## 1.0.0 (2026-09-09)

- Added exact Thunderbolt/USB4, serialized USB hub, and serialized adapter discovery.
- Added saved-source, any-external-power, and disconnect-only rules.
- Added owned disconnect/restore state, two-sample source debounce, bounded nonblocking retries, and guarded rollback when a source disappears during connection.
- Added validated same-boot runtime persistence and read-only status output.
- Added guided/noninteractive setup, dry-run, rule-preserving updates, legacy-watcher conflict detection, staged activation, backups, and rollback.
- Added fixture and simulated acceptance coverage for hardware, watcher, and installer behavior.
- Added a native AppKit controller with Overview, Speaker & Rule, and Diagnostics views.
- Added a script-free macOS Installer package that installs the universal app in `/Applications`.
- Updated the public documentation around app-first setup, package boundaries, live acceptance, and the rounded paper-cut icon.
