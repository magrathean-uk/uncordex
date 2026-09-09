# Releasing

## Preconditions

1. Update `VERSION` and `CHANGELOG.md`.
2. Confirm the MIT `LICENSE` and [third-party notices](../THIRD_PARTY_NOTICES.md) remain accurate.
3. Run the full source verification:

```bash
bash -n install.sh uninstall.sh watch-power lib/source.sh tests/run.sh
bash tests/run.sh
shellcheck install.sh uninstall.sh watch-power lib/source.sh tests/run.sh
```

Run the final command only when ShellCheck is installed. Record its absence if it is unavailable.

4. Inspect `git diff --check` and the intended release tree. Do not include `.serena/` or unrelated work.

## Publish

After verified source is on `main`, create an annotated tag:

```bash
git tag -a vX.Y.Z -m "Uncordex X.Y.Z"
git push origin vX.Y.Z
```

Create a GitHub release from the matching changelog section. State that automated verification is simulated and that physical hardware acceptance remains separate. Do not upload binaries, enable CI, publish a package, or imply a deployed service.

## Verify

Confirm repository metadata, default branch, MIT license detection, tag target, release status, and release URL through GitHub after publication. Preserve historic tags rather than moving them.
