# Contributing

Uncordex controls one already-paired Bluetooth speaker through a per-user macOS service. Keep changes focused on that behavior.

## Make a change

Read the relevant code and [development guide](../docs/development.md). Preserve unrelated work. Shell code must run with macOS Bash 3.2 and find Homebrew on both Apple Silicon and Intel.

Do not add accounts, telemetry, cloud services, automatic pairing, Bluetooth-radio control, or audio-output switching. Keep manual speaker actions respected and never broaden a saved-source rule silently.

For behavior changes, add a focused regression case that reproduces the issue. Substitute power, hardware, Bluetooth, time, filesystem paths, and LaunchAgent boundaries. Do not run the real installer, uninstaller, or Bluetooth operations as ordinary automated verification.

## Review a change

Describe the user-visible result, the checks performed, and any remaining acceptance gaps. Use the targeted checks in [Development](../docs/development.md); distinguish simulated tests, build and package inspection, fixture visuals, and physical hardware results.

Exclude local configuration, runtime state, logs, device addresses, source keys, credentials, and signing-account details from patches. Preserve the [MIT licence](../LICENSE) and [third-party notices](../THIRD_PARTY_NOTICES.md), including notices for anything newly distributed.

Use [Support](SUPPORT.md) for ordinary problems and [Security](SECURITY.md) for vulnerabilities. Publication, installation, signing, notarization, and live service changes are separate actions; existing authorization for an action does not need to be requested again.
