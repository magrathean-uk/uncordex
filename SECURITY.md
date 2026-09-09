# Security Policy — Uncordex

## Private reporting

Report vulnerabilities through GitHub private vulnerability reporting or email `contact@magrathean.uk` with subject `SECURITY: Uncordex`.

Do not publish credentials, private keys, database dumps, signing certificates, or exploit details. Include the affected version or commit, macOS version, hardware topology, reproduction steps, impact, and redacted evidence.

## Supported version

The current `1.x` release line is supported. Historic pre-Uncordex releases are retained for traceability but do not receive new fixes.

## Security boundaries

The app and watcher run as the logged-in user. They do not require a privileged daemon, account, remote service, inbound listener, telemetry endpoint, or bundled Bluetooth helper. The macOS package installs only `/Applications/Uncordex.app` and contains no installer scripts.

Reports involving the app's command boundary, LaunchAgent lifecycle, configuration or runtime-state integrity, source-identity matching, package contents, signing, or dependency discovery are in scope. Redact Bluetooth addresses, source keys, hardware serials, local paths containing user names, and log content unrelated to the finding.

## Scope and safe harbour

Magrathean UK Ltd. will not pursue a good-faith researcher for disclosures that:

- target non-production test systems or researcher-owned environments;
- avoid persistence, destructive changes, denial of service, and access to personal or customer data;
- report promptly and allow reasonable time for remediation; and
- do not condition non-disclosure on financial compensation.

## Excluded conduct

No safe harbour covers phishing, credential stuffing, accessing private production infrastructure, large-scale scanning, denial of service, or unlawful conduct.
