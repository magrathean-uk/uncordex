# Changelog

## 1.0.0 — 2026-09-09

- Added exact Thunderbolt/USB4, serialized USB hub, and serialized adapter discovery.
- Added saved-source, any-external-power, and disconnect-only rules.
- Added owned disconnect/restore state, two-sample source debounce, bounded nonblocking retries, and guarded rollback when a source disappears during connection.
- Added validated same-boot runtime persistence and read-only status output.
- Added guided/noninteractive setup, dry-run, rule-preserving updates, legacy-watcher conflict detection, staged activation, backups, and rollback.
- Added fixture and simulated acceptance coverage for hardware, watcher, and installer behavior.
