# Security Policy

## Reporting a vulnerability

Report sensitive issues to [contact@magrathean.uk](mailto:contact@magrathean.uk?subject=SECURITY%3A%20Uncordex). If **Report a vulnerability** is available on [the Uncordex repository](https://github.com/magrathean-uk/uncordex), use it for private reporting. Do not post credentials, private keys, signing certificates, database dumps, or exploit details in public issues.

Include the affected version or commit, macOS version, hardware topology, reproduction steps, impact, and redacted evidence. Redact Bluetooth addresses, source keys, hardware serials, user-name paths, and unrelated log content.

## Supported versions

The current `1.x` release line is supported. Historic pre-Uncordex releases are retained for traceability and do not receive new fixes.

## System scope and trust boundaries

Uncordex is a local macOS app and per-user watcher. It runs as the logged-in user and manages a single user LaunchAgent. The package installs `/Applications/Uncordex.app`; it contains no installer scripts and does not make user-session changes by itself.

The sensitive boundaries are the app's process execution, the LaunchAgent lifecycle, configuration and runtime-state files, source-identity detection, Bluetooth control through `blueutil`, and app-package contents, signing, and dependency discovery. The source installer can ask Homebrew to install `blueutil` unless setup uses `--no-install-dependencies` or `--dry-run`. The app uses the no-dependency-install option, and the package does not install Homebrew packages. The documented design has no account, cloud service, inbound listener, telemetry endpoint, bundled Bluetooth helper, privileged daemon, automatic pairing, or Bluetooth-radio control.

## Security properties

- User-entered speaker addresses and discovered source keys must be passed as process arguments, never interpolated into shell source.
- A source match must use a stable hardware identity. Missing, duplicate, malformed, or unreadable data must remain unknown rather than matching broadly.
- Automatic restoration must require a verified watcher-owned disconnect and a fresh eligible return. Startup, reboot, malformed state, changed rules, or unknown observations must not create restoration permission.
- Configuration and runtime state must use current-user access controls. Runtime state must be written atomically and accepted only when its schema, boot identity, and rule binding are valid.
- App-launched commands must use fixed executable paths, bounded execution, and one in-flight mutation at a time.
- Package changes must preserve the non-relocatable `/Applications/Uncordex.app` payload boundary and exclude installer scripts.

## Reportable issues

Report realistic issues that let an untrusted local input or package alter command execution, service lifecycle, configuration or runtime state, source matching, connection ownership, package integrity, signing, or dependency behavior beyond the intended logged-in-user boundary. Report evidence that fixture or simulated checks do not cover only when it demonstrates a reachable impact.

## Good-faith research and excluded conduct

MAGRATHEAN UK LTD will not pursue a good-faith researcher for disclosures that:

- target non-production test systems or researcher-owned environments;
- avoid persistence, destructive changes, denial of service, and access to personal or customer data;
- report promptly and allow reasonable time for remediation; and
- do not condition non-disclosure on financial compensation.

No safe harbour covers phishing, credential stuffing, accessing private production infrastructure, large-scale scanning, denial of service, or unlawful conduct.
