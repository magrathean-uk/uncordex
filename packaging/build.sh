#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVELOPMENT_BUILD_ROOT="$HOME/dev/build"
BUILD_ROOT="${UNCORDEX_PKG_BUILD_ROOT:-$DEVELOPMENT_BUILD_ROOT/uncordex/pkg}"
APP_IDENTITY="${UNCORDEX_APP_SIGN_IDENTITY:-}"
INSTALLER_IDENTITY="${UNCORDEX_INSTALLER_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${UNCORDEX_NOTARY_PROFILE:-}"
NOTARY_KEY="${UNCORDEX_NOTARY_KEY:-}"
NOTARY_KEY_ID="${UNCORDEX_NOTARY_KEY_ID:-}"
NOTARY_ISSUER="${UNCORDEX_NOTARY_ISSUER:-}"

fail() { /usr/bin/printf 'packaging/build.sh: %s\n' "$*" >&2; exit 1; }

case "$BUILD_ROOT" in
  "$DEVELOPMENT_BUILD_ROOT"|"$DEVELOPMENT_BUILD_ROOT"/*) ;;
  *) fail "UNCORDEX_PKG_BUILD_ROOT must stay under $DEVELOPMENT_BUILD_ROOT" ;;
esac
case "/$BUILD_ROOT/" in */../*|*/./*) fail "build root must not contain dot path components" ;; esac
/bin/mkdir -p "$DEVELOPMENT_BUILD_ROOT"
DEVELOPMENT_BUILD_ROOT="$(cd "$DEVELOPMENT_BUILD_ROOT" && pwd -P)"
BUILD_PROBE="$BUILD_ROOT"
while [ ! -e "$BUILD_PROBE" ]; do BUILD_PROBE="$(/usr/bin/dirname "$BUILD_PROBE")"; done
BUILD_PROBE="$(cd "$BUILD_PROBE" && pwd -P)"
case "$BUILD_PROBE" in "$DEVELOPMENT_BUILD_ROOT"|"$DEVELOPMENT_BUILD_ROOT"/*) ;; *) fail "build root traverses outside $DEVELOPMENT_BUILD_ROOT" ;; esac
/bin/mkdir -p "$BUILD_ROOT"
BUILD_ROOT="$(cd "$BUILD_ROOT" && pwd -P)"
case "$BUILD_ROOT" in "$DEVELOPMENT_BUILD_ROOT"|"$DEVELOPMENT_BUILD_ROOT"/*) ;; *) fail "build root resolves outside $DEVELOPMENT_BUILD_ROOT" ;; esac

for tool in codesign cp cpio gzip lipo mkbom pkgbuild pkgutil plutil productbuild sed shasum; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is required"
done

VERSION="$(/bin/cat "$ROOT_DIR/VERSION")"
case "$VERSION" in
  ''|*[!0-9.]*) fail "VERSION must contain only numeric dotted components" ;;
esac
/usr/bin/printf '%s\n' "$VERSION" | /usr/bin/grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || fail "VERSION must use X.Y.Z format"

if { [ -n "$APP_IDENTITY" ] && [ -z "$INSTALLER_IDENTITY" ]; } || { [ -z "$APP_IDENTITY" ] && [ -n "$INSTALLER_IDENTITY" ]; }; then
  fail "app and installer signing identities must be supplied together"
fi
if [ -n "$NOTARY_PROFILE$NOTARY_KEY$NOTARY_KEY_ID$NOTARY_ISSUER" ] && [ -z "$APP_IDENTITY" ]; then
  fail "notarization requires signed app and installer identities"
fi
if [ -n "$NOTARY_PROFILE" ] && [ -n "$NOTARY_KEY$NOTARY_KEY_ID$NOTARY_ISSUER" ]; then
  fail "use either a notary profile or API-key credentials"
fi
if [ -z "$NOTARY_PROFILE" ] && [ -n "$NOTARY_KEY$NOTARY_KEY_ID$NOTARY_ISSUER" ]; then
  [ -f "$NOTARY_KEY" ] && [ -n "$NOTARY_KEY_ID" ] && [ -n "$NOTARY_ISSUER" ] || fail "API-key notarization requires key, key ID, and issuer"
fi

GUI_ROOT="$BUILD_ROOT/gui"
STAGE_ROOT="$BUILD_ROOT/stage-root"
WORK_ROOT="$BUILD_ROOT/work"
VERIFY_ROOT="$BUILD_ROOT/verify"
COMPONENT_PKG="$WORK_ROOT/Uncordex-component.pkg"
OUTPUT_PKG="$BUILD_ROOT/Uncordex-$VERSION.pkg"
APP_BUNDLE="$GUI_ROOT/Uncordex.app"

for path in "$GUI_ROOT" "$STAGE_ROOT" "$WORK_ROOT" "$VERIFY_ROOT"; do
  if [ -e "$path" ]; then /usr/bin/find "$path" -depth -delete; fi
done
/bin/rm -f "$OUTPUT_PKG"
/bin/mkdir -p "$WORK_ROOT" "$STAGE_ROOT/Applications"

UNCORDEX_BUILD_ROOT="$GUI_ROOT" "$ROOT_DIR/app/build.sh"
[ -d "$APP_BUNDLE" ] || fail "app build did not produce Uncordex.app"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_BUNDLE/Contents/Info.plist")" = uk.magrathean.uncordex ] || fail "app identifier is unexpected"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")" = "$VERSION" ] || fail "app version does not match VERSION"
[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP_BUNDLE/Contents/Info.plist")" = 13.0 ] || fail "app minimum system version is not 13.0"
LIPO_INFO="$(/usr/bin/lipo -info "$APP_BUNDLE/Contents/MacOS/Uncordex")"
case "$LIPO_INFO" in *arm64*x86_64*|*x86_64*arm64*) ;; *) fail "app must contain arm64 and x86_64" ;; esac

if [ -n "$APP_IDENTITY" ]; then
  /usr/bin/codesign --force --sign "$APP_IDENTITY" --timestamp --options runtime "$APP_BUNDLE"
else
  /usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
fi
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
/bin/cp -R -X "$APP_BUNDLE" "$STAGE_ROOT/Applications/Uncordex.app"
/usr/bin/codesign --verify --deep --strict "$STAGE_ROOT/Applications/Uncordex.app"

if ! /usr/bin/pkgbuild \
  --root "$STAGE_ROOT" \
  --component-plist "$ROOT_DIR/packaging/component.plist" \
  --identifier uk.magrathean.uncordex.pkg \
  --version "$VERSION" \
  --install-location / \
  --ownership recommended \
  --min-os-version 13.0 \
  --compression latest \
  "$COMPONENT_PKG" 2>"$WORK_ROOT/pkgbuild.log"; then
  /bin/cat "$WORK_ROOT/pkgbuild.log" >&2
  fail "pkgbuild failed"
fi

# macOS provenance attributes can make pkgbuild emit AppleDouble `._*` entries.
# Rebuild the unsigned component payload from the explicit path list so those
# host-only attributes are never shipped to another Mac.
COMPONENT_EXPANDED="$WORK_ROOT/component-expanded"
/usr/sbin/pkgutil --expand "$COMPONENT_PKG" "$COMPONENT_EXPANDED"
(
  cd "$STAGE_ROOT"
  /usr/bin/find . ! -name '.DS_Store' -print \
    | COPYFILE_DISABLE=1 /usr/bin/cpio -o -H odc 2>"$WORK_ROOT/cpio.log" \
    | /usr/bin/gzip -c >"$COMPONENT_EXPANDED/Payload"
)
/usr/bin/mkbom "$STAGE_ROOT" "$COMPONENT_EXPANDED/Bom"
FILE_COUNT="$(/usr/bin/find "$STAGE_ROOT" -type f | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
INSTALL_KBYTES="$(/usr/bin/du -sk "$STAGE_ROOT" | /usr/bin/awk '{print $1}')"
/usr/bin/sed -E "s/numberOfFiles=\"[0-9]+\"/numberOfFiles=\"$FILE_COUNT\"/; s/installKBytes=\"[0-9]+\"/installKBytes=\"$INSTALL_KBYTES\"/" \
  "$COMPONENT_EXPANDED/PackageInfo" >"$WORK_ROOT/PackageInfo"
/bin/mv "$WORK_ROOT/PackageInfo" "$COMPONENT_EXPANDED/PackageInfo"
/bin/rm -f "$COMPONENT_PKG"
/usr/sbin/pkgutil --flatten "$COMPONENT_EXPANDED" "$COMPONENT_PKG"
if /usr/sbin/pkgutil --payload-files "$COMPONENT_PKG" | /usr/bin/grep -Eq '(^|/)\._|(^|/)\.DS_Store$'; then
  fail "component package contains host metadata files"
fi

/usr/bin/sed "s/@VERSION@/$VERSION/g" "$ROOT_DIR/packaging/Distribution.xml.in" >"$WORK_ROOT/Distribution.xml"
PRODUCT_ARGS=(--distribution "$WORK_ROOT/Distribution.xml" --package-path "$WORK_ROOT" --resources "$ROOT_DIR/packaging/Resources")
if [ -n "$INSTALLER_IDENTITY" ]; then PRODUCT_ARGS+=(--sign "$INSTALLER_IDENTITY" --timestamp); fi
/usr/bin/productbuild "${PRODUCT_ARGS[@]}" "$OUTPUT_PKG"

if [ -n "$NOTARY_PROFILE" ]; then
  xcrun notarytool submit "$OUTPUT_PKG" --keychain-profile "$NOTARY_PROFILE" --wait --timeout 30m --output-format json >"$WORK_ROOT/notary-submit.json"
elif [ -n "$NOTARY_KEY" ]; then
  xcrun notarytool submit "$OUTPUT_PKG" --key "$NOTARY_KEY" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER" --wait --timeout 30m --output-format json >"$WORK_ROOT/notary-submit.json"
fi
if [ -f "$WORK_ROOT/notary-submit.json" ]; then
  [ "$(/usr/bin/plutil -extract status raw -o - "$WORK_ROOT/notary-submit.json")" = Accepted ] || fail "Apple did not accept the package for notarization"
  xcrun stapler staple "$OUTPUT_PKG"
  xcrun stapler validate "$OUTPUT_PKG"
fi

VALIDATE_ARGS=()
if [ -n "$INSTALLER_IDENTITY" ]; then VALIDATE_ARGS+=(--require-signed); fi
if [ -f "$WORK_ROOT/notary-submit.json" ]; then VALIDATE_ARGS+=(--require-notarized); fi
UNCORDEX_PKG_VERIFY_ROOT="$VERIFY_ROOT" "$ROOT_DIR/packaging/validate.sh" "$OUTPUT_PKG" "${VALIDATE_ARGS[@]}"
/usr/bin/shasum -a 256 "$OUTPUT_PKG"
/usr/bin/printf 'Built %s\n' "$OUTPUT_PKG"
