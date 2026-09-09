# macOS installer package

The release package installs `Uncordex.app` into `/Applications`. Installation and upgrades replace only the app bundle. They do not run the app, bootstrap a LaunchAgent, operate Bluetooth, install Homebrew packages, or write per-user configuration.

The package is non-relocatable, requires macOS 13 or newer, and contains a universal arm64/x86_64 app. Its component identifier is `uk.magrathean.uncordex.pkg`. It contains no installer scripts or symbolic links.

After installation, open Uncordex from Applications. Install `blueutil` with Homebrew if needed, choose the paired speaker and reconnection rule, preview the setup, then choose **Save & Start**. That explicit app action updates and starts the logged-in user's service.

Existing configuration, state, logs, and LaunchAgent files are preserved when the app package is installed or upgraded. Applying setup in a newer app updates the service files used by that user.

## Build

An unsigned local-development package can be built with:

```bash
packaging/build.sh
```

For distribution, provide matching Developer ID identities:

```bash
UNCORDEX_APP_SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" \
UNCORDEX_INSTALLER_SIGN_IDENTITY="Developer ID Installer: Name (TEAMID)" \
packaging/build.sh
```

Set `UNCORDEX_NOTARY_PROFILE` to a saved `notarytool` keychain profile to submit, staple, and validate the package. The equivalent API-key variables are `UNCORDEX_NOTARY_KEY`, `UNCORDEX_NOTARY_KEY_ID`, and `UNCORDEX_NOTARY_ISSUER`. Credentials must remain outside the repository.

The artifact is written to `$HOME/dev/build/uncordex/pkg/Uncordex-<version>.pkg`. Intermediate files remain under the same build root.

The existing GitHub `v1.0.0` release predates the native app source and has no package asset. Do not attach the current package to that tag. A downloadable installer belongs on a new release whose tag contains the exact app and packaging source used to build it.

## Validation

The build validates the app identifier and version, macOS 13 minimum, arm64 and x86_64 slices, resource completeness, executable modes, package identifier and payload paths, absence of installer scripts, non-relocatable bundle policy, and available signatures. It expands the finished product archive and checks the packaged app, rather than trusting the source staging directory.

Run focused package checks independently with:

```bash
UNCORDEX_PKG_UNDER_TEST="$HOME/dev/build/uncordex/pkg/Uncordex-1.0.0.pkg" \
UNCORDEX_PKG_REQUIRE_SIGNED=1 \
packaging/test.sh
```

Use `UNCORDEX_PKG_REQUIRE_NOTARIZED=1` for a notarized package. A signed but unnotarized package is structurally valid but may be blocked by Gatekeeper when downloaded on another Mac.

The 1.0.0 package built from commit `c0de4f49b07961778ca875e034495cf621e68442` has SHA-256 `bb452684cfc59c2e9ae5c4b96305245da9944c5b5416e6178a7f10de4f4ed170`. It is Developer ID Application and Developer ID Installer signed for team `4AA2EMZ2HA`, timestamped, and intentionally not notarized.

That exact package was installed on the development Mac as a physical acceptance check. Native Installer registered the expected receipt, installed the universal app in `/Applications`, and did not restart the already-running per-user service. The installed app launched and displayed the live setup. This remains one-host evidence; macOS 13 and Intel installation still require separate host checks.

## Removal

Move `/Applications/Uncordex.app` to the Trash to remove the GUI. Use the app's service controls or `uninstall.sh` to stop and remove the per-user LaunchAgent first. Configuration, state, backups, and logs remain available for recovery unless removed separately by the user.

Removing the app does not forget the Installer receipt. A package-management workflow may remove receipt metadata separately, but that does not stop the per-user service or delete its data.
