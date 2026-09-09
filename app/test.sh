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
TEST_ROOT="$BUILD_ROOT/tests"
TMPDIR="$BUILD_ROOT/tmp"
SWIFT_MODULE_CACHE_PATH="$BUILD_ROOT/swift-module-cache"
CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/clang-module-cache"
export TMPDIR SWIFT_MODULE_CACHE_PATH CLANG_MODULE_CACHE_PATH
/bin/mkdir -p "$TEST_ROOT" "$TMPDIR" "$SWIFT_MODULE_CACHE_PATH" "$CLANG_MODULE_CACHE_PATH"

architecture="$(uname -m)"
SDK="$(xcrun --show-sdk-path)"
xcrun swiftc \
  -swift-version 5 \
  -parse-as-library \
  -target "$architecture-apple-macos13.0" \
  -sdk "$SDK" \
  -module-cache-path "$SWIFT_MODULE_CACHE_PATH" \
  "$ROOT_DIR/app/Sources/Models.swift" \
  "$ROOT_DIR/app/Sources/ProcessRunner.swift" \
  "$ROOT_DIR/app/Sources/ServiceAdapter.swift" \
  "$ROOT_DIR/app/Sources/AppModel.swift" \
  "$ROOT_DIR/app/Tests/AppTests.swift" \
  -o "$TEST_ROOT/UncordexTests"

"$TEST_ROOT/UncordexTests"
