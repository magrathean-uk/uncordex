# Live hardware test — 2026-09-09

Tested the real GUI with Bose SoundLink Max and ASUS PA32UCDM over Thunderbolt. User authorized pausing the legacy watcher and installing and starting Uncordex. The hardware cycle occurred before source publication; the tested app and package implementation was later committed as `2576d4431e8cda36cac5cbd6fafe06cf18af4c90` and pushed to `main`.

## Results

- Real GUI discovery found the paired Bose and exact ASUS source. Preview succeeded; Save & Start installed the canonical LaunchAgent.
- The legacy `com.bolyki.bt-auto-speaker-power` job was booted out. Its plist remains, so this pause lasts only for the current login session.
- At baseline, the new watcher was running, external power and the saved source matched, and Bluetooth reported the Bose connected.
- User unplugged Thunderbolt. Log at 12:34:56 BST: departure confirmed. At 12:34:58: disconnect verified and restore permission pending. Independent Bluetooth query returned `0`; watcher reported battery/source absent.
- User reconnected Thunderbolt. At 12:35:43: eligible return confirmed. At 12:35:44: reconnect attempt 1 of 6. At 12:35:45: reconnection verified. Independent query returned `1`; watcher reported AC/source match and idle, with no pending restore permission.
- Manually disconnected the Bose with the monitor attached. After an additional 18-second observation period, Bluetooth still returned `0`; watcher remained idle with no pending restore permission and no new reconnect log entries.
- Manually reconnected the Bose at the end; independent query returned `1`.
- Service error log was empty during the checks.
- Quitting/reopening the GUI during the status fix left the watcher running with the same PID (55505).

## Bug discovered and fixed

The GUI parsed nested `launchctl print` coalition states as the job state, showing a running job as “Loaded, not running — state: active.” The adapter now ignores nested dictionary fields. Two regression tests reproduced the issue before the fix; all 22 app tests passed afterward. Rebuilt the universal app and verified that the real Overview shows Running.

## Scope and remaining checks

This proves the observed basic disconnect/restore cycle and respect for a manual disconnect on this Mac. It does not prove wrong-source rejection on real hardware, retry exhaustion, sleep/wake, reboot/login behavior, or runtime compatibility with macOS 13.

Before a future login/reboot with Uncordex retained, resolve the legacy LaunchAgent's automatic startup: its plist remains enabled, and both watchers must not run together. No persistent disable or removal of the legacy service was performed in this test.

Evidence sources: `~/Library/Logs/uncordex.log`, `~/Library/Logs/uncordex-error.log`, installed watcher `--status`, independent `blueutil --is-connected`, and real app accessibility state.

## Package installation acceptance

The final signed `Uncordex-1.0.0.pkg` was installed on this Mac with the native command-line Installer. Installer completed successfully and registered receipt `uk.magrathean.uncordex.pkg` at version 1.0.0. The package placed `/Applications/Uncordex.app` on disk. Its SHA-256 is `cad60ac1a27f3475468a44ffca3a19ee18580af305d76965236ed577f7159167`.

The installed app passed strict code-signature validation with the Developer ID Application identity for team `4AA2EMZ2HA`. Its executable contains arm64 and x86_64 slices, its bundle version is 1.0.0, and its minimum system version is macOS 13.0. The installed app launched outside demo mode and showed the saved Bose/ASUS setup and the live watcher as Running.

The watcher PID was 55505 immediately before and after package installation. This confirms the observed install did not restart the existing per-user service. Quitting the installed GUI also left that service running.

The package is Developer ID signed with a trusted timestamp but, by user choice, was not submitted to Apple for notarization.

## Final simulated verification

After the GUI status parser and package payload fixes, the final implementation passed 113 service tests, 22 native-app tests, and 3 package tests. Bash syntax validation, ShellCheck, strict app signature validation, package signature inspection, local Markdown-link checks, and the absence of AppleDouble or `.DS_Store` payload files also passed.

These checks support the recorded implementation and package. They do not widen the one-host hardware evidence described above.
