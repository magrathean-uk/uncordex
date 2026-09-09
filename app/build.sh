#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVELOPMENT_BUILD_ROOT="$HOME/dev/build"
BUILD_ROOT="${UNCORDEX_BUILD_ROOT:-$DEVELOPMENT_BUILD_ROOT/uncordex/gui}"
case "$BUILD_ROOT" in
  "$DEVELOPMENT_BUILD_ROOT"|"$DEVELOPMENT_BUILD_ROOT"/*) ;;
  *) /usr/bin/printf 'UNCORDEX_BUILD_ROOT must stay under %s\n' "$DEVELOPMENT_BUILD_ROOT" >&2; exit 64 ;;
esac
case "/$BUILD_ROOT/" in
  */../*|*/./*) /usr/bin/printf '%s\n' 'UNCORDEX_BUILD_ROOT must not contain dot path components' >&2; exit 64 ;;
esac
/bin/mkdir -p "$DEVELOPMENT_BUILD_ROOT"
DEVELOPMENT_BUILD_ROOT="$(cd "$DEVELOPMENT_BUILD_ROOT" && pwd -P)"
BUILD_PROBE="$BUILD_ROOT"
while [ ! -e "$BUILD_PROBE" ]; do BUILD_PROBE="$(/usr/bin/dirname "$BUILD_PROBE")"; done
BUILD_PROBE="$(cd "$BUILD_PROBE" && pwd -P)"
case "$BUILD_PROBE" in
  "$DEVELOPMENT_BUILD_ROOT"|"$DEVELOPMENT_BUILD_ROOT"/*) ;;
  *) /usr/bin/printf 'UNCORDEX_BUILD_ROOT traverses outside %s\n' "$DEVELOPMENT_BUILD_ROOT" >&2; exit 64 ;;
esac
/bin/mkdir -p "$BUILD_ROOT"
BUILD_ROOT="$(cd "$BUILD_ROOT" && pwd -P)"
case "$BUILD_ROOT" in
  "$DEVELOPMENT_BUILD_ROOT"|"$DEVELOPMENT_BUILD_ROOT"/*) ;;
  *) /usr/bin/printf 'UNCORDEX_BUILD_ROOT resolves outside %s\n' "$DEVELOPMENT_BUILD_ROOT" >&2; exit 64 ;;
esac
APP_BUNDLE="$BUILD_ROOT/Uncordex.app"
TMPDIR="$BUILD_ROOT/tmp"
SWIFT_MODULE_CACHE_PATH="$BUILD_ROOT/swift-module-cache"
CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/clang-module-cache"
export TMPDIR SWIFT_MODULE_CACHE_PATH CLANG_MODULE_CACHE_PATH
/bin/mkdir -p "$TMPDIR" "$SWIFT_MODULE_CACHE_PATH" "$CLANG_MODULE_CACHE_PATH" "$BUILD_ROOT/arm64" "$BUILD_ROOT/x86_64"
/bin/rm -rf "$APP_BUNDLE"
/bin/mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources/Service/lib"

SDK="$(xcrun --show-sdk-path)"
SOURCES=("$ROOT_DIR"/app/Sources/*.swift)
for architecture in arm64 x86_64; do
  xcrun swiftc \
    -swift-version 5 \
    -parse-as-library \
    -target "$architecture-apple-macos13.0" \
    -sdk "$SDK" \
    -module-cache-path "$SWIFT_MODULE_CACHE_PATH" \
    -O \
    "${SOURCES[@]}" \
    -o "$BUILD_ROOT/$architecture/Uncordex"
done

/usr/bin/lipo -create "$BUILD_ROOT/arm64/Uncordex" "$BUILD_ROOT/x86_64/Uncordex" -output "$APP_BUNDLE/Contents/MacOS/Uncordex"
/bin/cp "$ROOT_DIR/app/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
VERSION="$(/bin/cat "$ROOT_DIR/VERSION")"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP_BUNDLE/Contents/Info.plist"

/usr/bin/install -m 755 "$ROOT_DIR/install.sh" "$ROOT_DIR/uninstall.sh" "$ROOT_DIR/watch-power" "$APP_BUNDLE/Contents/Resources/Service/"
/usr/bin/install -m 644 "$ROOT_DIR/lib/source.sh" "$APP_BUNDLE/Contents/Resources/Service/lib/source.sh"
/usr/bin/install -m 644 "$ROOT_DIR/VERSION" "$ROOT_DIR/LICENSE" "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$APP_BUNDLE/Contents/Resources/Service/"
/usr/bin/install -m 644 "$ROOT_DIR/icon/Uncordex.icns" "$APP_BUNDLE/Contents/Resources/Uncordex.icns"
/bin/chmod 755 "$APP_BUNDLE/Contents/MacOS/Uncordex"
/usr/bin/codesign --force --sign - --timestamp=none "$APP_BUNDLE"

/usr/bin/printf 'Built %s\n' "$APP_BUNDLE"
/usr/bin/lipo -info "$APP_BUNDLE/Contents/MacOS/Uncordex"
