#!/bin/bash
set -euo pipefail

PACKAGE="${1:-}"
shift || true
REQUIRE_SIGNED=0
REQUIRE_NOTARIZED=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --require-signed) REQUIRE_SIGNED=1 ;;
    --require-notarized) REQUIRE_NOTARIZED=1; REQUIRE_SIGNED=1 ;;
    *) /usr/bin/printf 'packaging/validate.sh: unknown option: %s\n' "$1" >&2; exit 64 ;;
  esac
  shift
done
[ -f "$PACKAGE" ] || { /usr/bin/printf 'packaging/validate.sh: package is missing\n' >&2; exit 1; }

VERIFY_ROOT="${UNCORDEX_PKG_VERIFY_ROOT:-$HOME/dev/build/uncordex/pkg/verify-standalone}"
case "$VERIFY_ROOT" in "$HOME/dev/build"|"$HOME/dev/build"/*) ;; *) /usr/bin/printf 'packaging/validate.sh: verify root must stay under %s\n' "$HOME/dev/build" >&2; exit 1 ;; esac
if [ -e "$VERIFY_ROOT" ]; then /usr/bin/find "$VERIFY_ROOT" -depth -delete; fi
/bin/mkdir -p "$VERIFY_ROOT"

SIGNATURE="$(/usr/sbin/pkgutil --check-signature "$PACKAGE" 2>&1)"
if [ "$REQUIRE_SIGNED" -eq 1 ]; then
  case "$SIGNATURE" in
    *'Developer ID Installer'*) ;;
    *) /usr/bin/printf '%s\n' "$SIGNATURE" >&2; exit 1 ;;
  esac
fi
/usr/sbin/pkgutil --expand-full "$PACKAGE" "$VERIFY_ROOT/expanded"

DIST="$VERIFY_ROOT/expanded/Distribution"
COMPONENT="$VERIFY_ROOT/expanded/Uncordex-component.pkg"
PAYLOAD="$COMPONENT/Payload"
APP="$PAYLOAD/Applications/Uncordex.app"
[ -f "$DIST" ] && [ -d "$APP" ] || { /usr/bin/printf 'packaging/validate.sh: expected package payload is missing\n' >&2; exit 1; }
/usr/bin/xmllint --noout "$DIST"
/usr/bin/grep -Fq 'hostArchitectures="arm64,x86_64"' "$DIST"
/usr/bin/grep -Fq '<os-version min="13.0"' "$DIST"
/usr/bin/grep -Fq 'uk.magrathean.uncordex.pkg' "$DIST"

PACKAGE_INFO="$COMPONENT/PackageInfo"
[ "$(/usr/bin/xmllint --xpath 'string(/pkg-info/@identifier)' "$PACKAGE_INFO")" = uk.magrathean.uncordex.pkg ]
[ "$(/usr/bin/xmllint --xpath 'string(/pkg-info/@install-location)' "$PACKAGE_INFO")" = / ]
[ "$(/usr/bin/xmllint --xpath 'string(/pkg-info/@relocatable)' "$PACKAGE_INFO")" = false ]
[ "$(/usr/bin/xmllint --xpath 'string(/pkg-info/@auth)' "$PACKAGE_INFO")" = root ]
[ "$(/usr/bin/xmllint --xpath 'string(/pkg-info/@minimumSystemVersion)' "$PACKAGE_INFO")" = 13.0 ]
[ ! -e "$COMPONENT/Scripts" ]
[ -z "$(/usr/bin/find "$PAYLOAD" -type l -print -quit)" ]
[ -z "$(/usr/bin/find "$PAYLOAD" \( -name '._*' -o -name '.DS_Store' \) -print -quit)" ]
if /usr/bin/lsbom "$COMPONENT/Bom" | /usr/bin/grep -Eq '(^|/)\._|(^|/)\.DS_Store$'; then exit 1; fi
[ "$(/usr/bin/find "$PAYLOAD" -mindepth 1 -maxdepth 1 -print)" = "$PAYLOAD/Applications" ]
[ "$(/usr/bin/find "$PAYLOAD/Applications" -mindepth 1 -maxdepth 1 -print)" = "$APP" ]
for resource in Welcome.txt ReadMe.txt License.txt; do
  [ -f "$VERIFY_ROOT/expanded/Resources/$resource" ] || exit 1
done

INFO="$APP/Contents/Info.plist"
/usr/bin/plutil -lint "$INFO" >/dev/null
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO")" = uk.magrathean.uncordex ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$INFO")" = 13.0 ]
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO")"
[ "$(/usr/bin/xmllint --xpath 'string(/pkg-info/@version)' "$PACKAGE_INFO")" = "$VERSION" ]
LIPO_INFO="$(/usr/bin/lipo -info "$APP/Contents/MacOS/Uncordex")"
case "$LIPO_INFO" in *arm64*x86_64*|*x86_64*arm64*) ;; *) exit 1 ;; esac
for required in Uncordex.icns Service/install.sh Service/uninstall.sh Service/watch-power Service/lib/source.sh Service/VERSION Service/LICENSE Service/THIRD_PARTY_NOTICES.md; do
  [ -e "$APP/Contents/Resources/$required" ] || { /usr/bin/printf 'packaging/validate.sh: missing app resource %s\n' "$required" >&2; exit 1; }
done
[ -x "$APP/Contents/MacOS/Uncordex" ]
[ -x "$APP/Contents/Resources/Service/install.sh" ]
[ -x "$APP/Contents/Resources/Service/uninstall.sh" ]
[ -x "$APP/Contents/Resources/Service/watch-power" ]
/usr/bin/codesign --verify --deep --strict "$APP"
if [ "$REQUIRE_SIGNED" -eq 1 ]; then
  APP_SIGNATURE="$(/usr/bin/codesign -d --verbose=4 "$APP" 2>&1)"
  case "$APP_SIGNATURE" in *'Authority=Developer ID Application'*) ;; *) exit 1 ;; esac
fi
if [ "$REQUIRE_NOTARIZED" -eq 1 ]; then
  xcrun stapler validate "$PACKAGE"
  /usr/sbin/spctl --assess --type install --verbose=2 "$PACKAGE"
fi
/usr/sbin/installer -pkg "$PACKAGE" -target / -showChoicesXML >/dev/null
/usr/bin/printf 'Validated Uncordex %s package payload, metadata, architectures, resources, modes, and signatures.\n' "$VERSION"
