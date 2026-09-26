# Licensing

Uncordex is provided under the MIT License. The complete, controlling license text is in the repository root at [LICENSE](../LICENSE). This document explains the repository layout and does not change that grant.

The root license carries the existing copyright notice for Magrathean UK Ltd. It grants permission to use, copy, modify, merge, publish, distribute, sublicense, and sell copies subject to including the notice and license text. It also contains the complete warranty and liability disclaimer. Do not replace or edit the root license text without qualified review of the rights involved.

## Packaged copy

The macOS installer displays `packaging/Resources/License.txt`. It preserves the MIT terms and existing copyright notice, then identifies blueutil as a third-party dependency. Keep that resource aligned with the root license and [third-party notices](../THIRD_PARTY_NOTICES.md).

## Third-party software

Uncordex relies on [blueutil](https://github.com/toy/blueutil), identified in [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) as MIT licensed. The observed upstream [LICENSE.txt](https://github.com/toy/blueutil/blob/main/LICENSE.txt) contains the MIT terms and credits Frederik Seiffert and Ivan Kuchin. The source tree says blueutil is installed and operated locally by the user and is not bundled in the app or installer package. Source setup can request its Homebrew installation unless `--no-install-dependencies` or `--dry-run` is used. Verify any new dependency's license, attribution, distribution model, and required notices before release.
