# Security Review: uncordex

## Scope

Read-only offline Standard repository security audit of Uncordex HEAD bc23724a5e2ffd83382c65238eafdb7dd94ff4e6.

- Scan mode: repository
- Target kind: git_worktree
- Target ID: target_sha256_6651a7724de6445898fc9d31272da554029b650e832210a2450e534bfee9d66c
- Revision: bc23724a5e2ffd83382c65238eafdb7dd94ff4e6
- Snapshot digest: codex-security-snapshot/v1:sha256:3e7b519c090c172a5444a179e284556730b2936ca45b955f37eded3e3ec1fd5c
- Inventory strategy: repository
- Included paths: .
- Excluded paths: none
- Artifacts reviewed: AGENTS.md, install.sh, uninstall.sh, watch-power, lib/source.sh, app/Sources/ProcessRunner.swift, app/Sources/ServiceAdapter.swift, app/build.sh, app/Tests/AppTests.swift, packaging/build.sh, packaging/validate.sh, packaging/Distribution.xml.in, app/Info.plist, tests/run.sh, relevant documentation
- Scan context: macOS local per-user Bluetooth speaker watcher, shell install/service, Swift app and package tooling.

Limitations and exclusions:
- Static source review only; no builds, tests, physical hardware, LaunchAgent, Homebrew, installs, network or package execution.
- Pre-existing modified AGENTS.md preserved untouched.

### Scan Summary

| Field | Value |
| --- | --- |
| Scan outcome | completed |
| Reportable findings | 0 |
| Severity mix | none |
| Confidence mix | none |
| Coverage | partial |
| Validation mode | static |

Canonical artifacts: `scan-manifest.json`, `findings.json`, and `coverage.json`. This report is a deterministic projection of those files.

## Threat Model

Local macOS app and per-user LaunchAgent watches power/source hardware and manages one already-paired Bluetooth speaker; shell install/service and Swift UI coordinate through private user state.

### Assets

- Chosen speaker MAC/address and source hardware key
- Per-user configuration, runtime state and logs
- Bluetooth connection state of already-paired device
- User LaunchAgent and packaged app/service integrity

### Trust Boundaries

- Local hardware/system_profiler/IORegistry/blueutil output to source matcher and watcher decisions
- User config and runtime files to shell/Swift service execution
- App UI input to ProcessRunner and install/uninstall/service commands
- Packaged payload/postinstall to per-user LaunchAgent location

### Attacker Capabilities

- Unprivileged local actor may tamper with files they can write or spoof tool output in unsafe environments
- Malicious/malformed hardware enumeration or duplicate source keys may confuse matching
- User may supply malformed device addresses/paths/config
- Concurrent app/service lifecycle could race state ownership

### Security Objectives

- Fail closed on missing/duplicate/malformed/unreadable hardware identity
- Reconnect only a device the watcher previously disconnected and verified
- Keep config/state/logs private to current user
- Avoid command injection, unsafe symlink writes or privilege escalation in installers and process calls

### Assumptions

- Offline static read-only audit; no real Bluetooth or LaunchAgent actions, installers, builds/tests or network.
- Pre-existing dirty AGENTS.md preserved untouched.
- No privileged daemon or cloud services in intended design.

## Findings

### No findings

No reportable findings survived the canonical discovery, validation, and reportability gates.

## Reviewed Surfaces

| Surface | Risk Area | Outcome | Notes |
| --- | --- | --- | --- |
| Source matching and watcher ownership | Device action authorization | No issue found | No additional canonical notes were recorded. |
| Install/uninstall/LaunchAgent lifecycle | Path/permission/symlink | No issue found | No additional canonical notes were recorded. |
| Swift app/process boundary | Command and private state | No issue found | No additional canonical notes were recorded. |
| Packaging and scripts | Payload integrity/privileges | No issue found | No additional canonical notes were recorded. |
| Tests/docs/fixtures | Security contract evidence | No issue found | No additional canonical notes were recorded. |

## Open Questions And Follow Up

- Physical Bluetooth, LaunchAgent, Homebrew, install/uninstall, builds, tests and package execution were not performed in this read-only static scan; host file permissions and third-party tool output were not verified.
  - Follow-up prompt: Review deferred unit uncordex-runtime-verification and close its stated proof gap. Paths: install.sh, watch-power, app, packaging.
