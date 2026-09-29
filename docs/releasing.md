# Releasing

Keep each distributed artifact tied to one immutable source commit. Source publication, tagging, signing, notarization, installation, and uploading assets are separate actions. Carry out the actions authorized for the release without repeating already-resolved approval questions.

## Prepare

1. Update `VERSION` and `CHANGELOG.md`. Confirm app and package metadata derive that version.
2. Check [licensing](licensing.md), the complete `LICENSE`, and [third-party notices](../THIRD_PARTY_NOTICES.md) against the material being distributed.
3. Run the relevant [development checks](development.md), including the service and app suites for a release. Inspect fixture visuals for UI changes.
4. Review the diff and documentation links. Exclude credentials, local account details, device identifiers, logs, generated output, and unrelated changes.
5. Record the tested commit and any physical acceptance limits. Commit and publish the verified source when those actions are authorized.

## Tag and package

Create a new tag on the verified release commit. Do not move an existing public tag or use an old tag for newer app/package source. The tag, `VERSION`, release notes, and artifact must describe the same source tree.

Follow [Packaging](pkg.md) for building and validating the exact distribution artifact. Record its SHA-256, signing result, and notarization result. An unsigned development package, a Developer ID signed package, and a notarized package are different results. Report the one actually verified.

If installation acceptance is part of the release, test the exact artifact on the intended host with authorization for service and hardware changes. Keep that result separate from archive validation and simulated tests.

## Publish and check

Release notes should state the user-visible changes, source commit, checks, hardware limits, and signing/notarization status. Include the package SHA-256 for any installer asset. Upload only an artifact built from the tagged source.

Read back the published tag target, release body, assets, and public links. Retrieve the published installer and compare its hash and signature with the verified artifact. A successful upload alone does not establish installation or hardware acceptance.

Do not add GitHub CI or security automation as part of this process. Preserve historical tags and keep historical release notes accurate about their original source and artifacts.
