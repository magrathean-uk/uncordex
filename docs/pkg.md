# macOS package

The Installer package places `Uncordex.app` in `/Applications`. It contains no installer scripts. Installing or upgrading the package does not launch the app, start a LaunchAgent, install dependencies, change Bluetooth, or update per-user setup. **Save & Start** in the app performs the separate service update.

The package is non-relocatable, targets macOS 13 or newer, and uses component identifier `uk.magrathean.uncordex.pkg`. Its app is built with arm64 and x86_64 slices. These are build requirements, not evidence of runtime acceptance on every supported host.

## Build locally

```bash
bash packaging/build.sh
```

The default artifact is `$HOME/dev/build/uncordex/pkg/Uncordex-<version>.pkg`, using `VERSION`. `UNCORDEX_PKG_BUILD_ROOT` selects a dedicated directory under `$HOME/dev/build`. The script replaces its work directories and output artifact. Without signing identities it builds an unsigned development package containing an ad-hoc-signed app.

For an authorized distribution build, supply both identities:

```bash
UNCORDEX_APP_SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" \
UNCORDEX_INSTALLER_SIGN_IDENTITY="Developer ID Installer: Name (TEAMID)" \
  bash packaging/build.sh
```

Notarization submits the package to Apple. For that separately authorized action, supply either `UNCORDEX_NOTARY_PROFILE` for an existing `notarytool` keychain profile, or all three API-key variables: `UNCORDEX_NOTARY_KEY`, `UNCORDEX_NOTARY_KEY_ID`, and `UNCORDEX_NOTARY_ISSUER`. Keep credentials outside the repository. The build waits for acceptance before stapling and validating the ticket.

## Validate the artifact

```bash
version="$(cat VERSION)"
UNCORDEX_PKG_UNDER_TEST="$HOME/dev/build/uncordex/pkg/Uncordex-$version.pkg" \
UNCORDEX_PKG_REQUIRE_SIGNED=1 \
  bash packaging/test.sh
```

Omit the signature requirement for an unsigned development package. Add `UNCORDEX_PKG_REQUIRE_NOTARIZED=1` when testing a notarized artifact. `UNCORDEX_PKG_TEST_ROOT` selects a dedicated test directory below `$HOME/dev/build`; the suite clears and recreates it. Standalone validation uses `UNCORDEX_PKG_VERIFY_ROOT` under the same development tree and also replaces its selected workspace.

Validation expands the finished archive and inspects payload paths, identifiers, versions, architectures, resources, modes, signatures, Installer choices, and absence of scripts, symlinks, and host metadata. It does not install the package. Without a supplied artifact, the test suite runs rejection cases only.

Use [Releasing](releasing.md) to tie an artifact to its source commit. Consult [GitHub releases](https://github.com/magrathean-uk/uncordex/releases) for published assets and their stated signing status. A local build is not a published release. The [dated package acceptance record](testing/2026-09-09-live-acceptance.md) applies only to the artifact identified there.

## Remove

Stop the service first if it is no longer wanted. The app's Stop control retains its files; `uninstall.sh` removes the canonical LaunchAgent plist after stopping the job. Move `/Applications/Uncordex.app` to the Trash to remove the GUI.

Removing the GUI does not stop the watcher. Configuration, runtime state, backups, and logs remain available for recovery. Removing the app also leaves the Installer receipt; receipt removal alone would not stop a service or delete its data.
