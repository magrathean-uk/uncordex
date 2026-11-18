# Changelog

Entries describe repository development. Consult the matching tag before treating an entry as a release.

## 2.0.1 (2026-11-18)

- Bluetooth access now belongs to Uncordex rather than the terminal app. Terminal apps such as Terminal and Warp declare no Bluetooth use, so macOS stopped `blueutil` without asking. The installer now builds a tiny helper, `Uncordex.app`, that runs `blueutil` and the watcher; macOS asks once whether Uncordex may use Bluetooth, and setup opens the Settings page and waits if access was refused.

## 2.0.0 (2026-11-18)

- Removed the GUI app and the macOS package.
- Added a single `uncordex` command with `setup`, `status`, `start`, `stop`, `restart`, `logs`, `devices`, `sources` and `uninstall`.
- Added numbered choices for the speaker and the dock or charger.
- Added a one-line installer.
- `install.sh` no longer performs setup; use `uncordex setup`.
- `uninstall.sh` is replaced by `uncordex uninstall`.
- Existing configuration and the LaunchAgent stay compatible.
- Install the watcher under `XDG_DATA_HOME` when it is set (default unchanged when it is not). An existing installation at the previous default stays in place until you remove it.
- Require fresh source confirmation after unreadable observations and retain the reconnect budget when readings become unknown during an attempt.
- Preserve running-service files when setup or uninstall cannot stop the LaunchAgent; reject repeated or conflicting setup options.

## 1.0.0 (2026-09-09)

- Added exact Thunderbolt/USB4, serialized USB hub, and serialized adapter discovery.
- Added saved-source, any-external-power, and disconnect-only rules.
- Added owned disconnect/restore state, two-sample source debounce, bounded nonblocking retries, and guarded rollback when a source disappears during connection.
- Added validated same-boot runtime persistence and read-only status output.
- Added guided/noninteractive setup, dry-run, rule-preserving updates, legacy-watcher conflict detection, staged activation, backups, and rollback.
- Added fixture and simulated acceptance coverage for hardware, watcher, and installer behavior.
- Added a native AppKit controller (removed in 2.0.0) with Overview, Speaker & Rule, and Diagnostics views.
- Added a script-free macOS Installer package that installs the universal app in `/Applications`.
- Updated the public documentation around app-first setup, package boundaries, live acceptance, and the rounded paper-cut icon.
