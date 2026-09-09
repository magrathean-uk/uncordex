# Releasing

Source publication, tag creation, package signing, notarization, and uploading a GitHub release asset are separate actions. Perform only the actions approved for that release, and keep every artifact tied to one immutable commit.

## Prepare the source

1. Update `VERSION` and `CHANGELOG.md`.
2. Confirm the MIT `LICENSE` and [third-party notices](../THIRD_PARTY_NOTICES.md) remain accurate.
3. Confirm the app bundle and package metadata derive the same version from `VERSION`.
4. Run the full source verification:

```bash
bash -n \
  install.sh uninstall.sh watch-power lib/source.sh tests/run.sh \
  app/build.sh app/test.sh \
  packaging/build.sh packaging/validate.sh packaging/test.sh
bash tests/run.sh
bash app/test.sh
```

Run ShellCheck when it is installed:

```bash
shellcheck \
  install.sh uninstall.sh watch-power lib/source.sh tests/run.sh \
  app/build.sh app/test.sh \
  packaging/build.sh packaging/validate.sh packaging/test.sh
```

5. Inspect `git diff --check`, local Markdown links, and the intended release tree. Exclude `.serena/`, build output, credentials, logs, device identifiers, and unrelated work.
6. Commit and push the verified source before creating a tag.

## Tag the release

Create the annotated tag from the exact verified release commit:

```bash
git tag -a vX.Y.Z -m "Uncordex X.Y.Z"
git push origin vX.Y.Z
```

Never move an existing public tag to include later work. If a published tag does not contain the intended app or package source, prepare a new patch or minor version.

## Build a distribution package

Use matching Developer ID identities with the tagged source:

```bash
UNCORDEX_APP_SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" \
UNCORDEX_INSTALLER_SIGN_IDENTITY="Developer ID Installer: Name (TEAMID)" \
packaging/build.sh
```

Signing credentials remain outside the repository. Record the package SHA-256 printed by the build.

Notarization is optional only when the approved release scope says so. For a notarized release, configure the documented `notarytool` credentials before building; the build waits for acceptance, staples the ticket, and validates it. Do not describe a signed-only package as notarized.

Validate the exact artifact intended for distribution:

```bash
UNCORDEX_PKG_UNDER_TEST="$HOME/dev/build/uncordex/pkg/Uncordex-X.Y.Z.pkg" \
UNCORDEX_PKG_REQUIRE_SIGNED=1 \
packaging/test.sh
```

Use `UNCORDEX_PKG_REQUIRE_NOTARIZED=1` when notarization is part of the release.

## Publish on GitHub

Create or update the GitHub release only after verifying that its tag targets the source used for the artifact. Release notes should state:

- the concrete user-visible changes;
- source, app, and package verification results;
- package signing and notarization status;
- the package SHA-256 when an installer is attached; and
- the boundary between simulated checks and physical hardware acceptance.

Uploading a package is a separate publishing action. Do not attach a locally built package to an older tag that lacks its source. Do not enable GitHub CI or claim installation, hardware acceptance, notarization, or deployment without direct evidence.

## Verify publication

Read back the repository default branch, tag target, release body, release assets, license detection, and public URLs. When a package is attached, download or otherwise retrieve the published asset through a clean read path and confirm its hash and signature against the recorded artifact.

Preserve historical tags and release notes as immutable evidence. Correct stale statements in the release body only when the correction does not misrepresent what the tagged source contained.
