#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVELOPMENT_BUILD_ROOT="${CLEAN_DEVELOPMENT_BUILD_ROOT:-${CLEAN_DEVELOPMENT_ROOT:+$CLEAN_DEVELOPMENT_ROOT/builds}}"
DEVELOPMENT_BUILD_ROOT="${DEVELOPMENT_BUILD_ROOT:-$HOME/dev/build}"
TEST_ROOT="${UNCORDEX_PKG_TEST_ROOT:-$DEVELOPMENT_BUILD_ROOT/uncordex/pkg-tests}"
case "$TEST_ROOT" in "$DEVELOPMENT_BUILD_ROOT"/*) ;; *) /usr/bin/printf 'packaging/test.sh: test root must stay below %s\n' "$DEVELOPMENT_BUILD_ROOT" >&2; exit 1 ;; esac
case "/$TEST_ROOT/" in */../*|*/./*) /usr/bin/printf '%s\n' 'packaging/test.sh: test root must not contain dot path components' >&2; exit 1 ;; esac
/bin/mkdir -p "$DEVELOPMENT_BUILD_ROOT"
DEVELOPMENT_BUILD_ROOT="$(cd "$DEVELOPMENT_BUILD_ROOT" && pwd -P)"
TEST_ROOT_EXISTS=0
[ ! -e "$TEST_ROOT" ] || TEST_ROOT_EXISTS=1
TEST_PROBE="$TEST_ROOT"
while [ ! -e "$TEST_PROBE" ]; do TEST_PROBE="$(/usr/bin/dirname "$TEST_PROBE")"; done
TEST_PROBE="$(cd "$TEST_PROBE" && pwd -P)"
case "$TEST_PROBE" in
  "$DEVELOPMENT_BUILD_ROOT"/*) ;;
  "$DEVELOPMENT_BUILD_ROOT") [ "$TEST_ROOT_EXISTS" -eq 0 ] || { /usr/bin/printf 'packaging/test.sh: test root resolves to %s\n' "$DEVELOPMENT_BUILD_ROOT" >&2; exit 1; } ;;
  *) /usr/bin/printf 'packaging/test.sh: test root traverses outside %s\n' "$DEVELOPMENT_BUILD_ROOT" >&2; exit 1 ;;
esac
if [ "$TEST_ROOT_EXISTS" -eq 1 ]; then /usr/bin/find "$TEST_ROOT" -depth -delete; fi
/bin/mkdir -p "$TEST_ROOT"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
case "$TEST_ROOT" in "$DEVELOPMENT_BUILD_ROOT"/*) ;; *) /usr/bin/printf 'packaging/test.sh: test root resolves outside %s\n' "$DEVELOPMENT_BUILD_ROOT" >&2; exit 1 ;; esac

passed=0
failed=0
check() {
  if "$@"; then passed=$((passed + 1)); /usr/bin/printf 'ok - %s\n' "$*"
  else failed=$((failed + 1)); /usr/bin/printf 'not ok - %s\n' "$*"
  fi
}

GUARD_ROOT="$TEST_ROOT/cleanup-guard"
/bin/mkdir -p "$GUARD_ROOT"
/usr/bin/printf '%s\n' 'keep this fixture' >"$GUARD_ROOT/sentinel"
/usr/bin/printf '%s\n' 'not a package' >"$TEST_ROOT/guard-input.pkg"
if UNCORDEX_PKG_VERIFY_ROOT="$GUARD_ROOT/../cleanup-guard" "$ROOT_DIR/packaging/validate.sh" "$TEST_ROOT/guard-input.pkg" >/dev/null 2>&1; then
  failed=$((failed + 1)); /usr/bin/printf '%s\n' 'not ok - dot components are rejected before cleanup'
else
  passed=$((passed + 1)); /usr/bin/printf '%s\n' 'ok - dot components are rejected before cleanup'
fi
check test -f "$GUARD_ROOT/sentinel"

if UNCORDEX_PKG_VERIFY_ROOT="$TEST_ROOT/missing-verify" "$ROOT_DIR/packaging/validate.sh" "$TEST_ROOT/missing.pkg" >/dev/null 2>&1; then
  failed=$((failed + 1)); /usr/bin/printf 'not ok - missing package is rejected\n'
else
  passed=$((passed + 1)); /usr/bin/printf 'ok - missing package is rejected\n'
fi
/usr/bin/printf '%s\n' 'not a package' >"$TEST_ROOT/malformed.pkg"
if UNCORDEX_PKG_VERIFY_ROOT="$TEST_ROOT/malformed-verify" "$ROOT_DIR/packaging/validate.sh" "$TEST_ROOT/malformed.pkg" >/dev/null 2>&1; then
  failed=$((failed + 1)); /usr/bin/printf 'not ok - malformed package is rejected\n'
else
  passed=$((passed + 1)); /usr/bin/printf 'ok - malformed package is rejected\n'
fi

PACKAGE="${UNCORDEX_PKG_UNDER_TEST:-}"
if [ -n "$PACKAGE" ]; then
  VALIDATE_ARGS=()
  [ "${UNCORDEX_PKG_REQUIRE_SIGNED:-0}" = 1 ] && VALIDATE_ARGS+=(--require-signed)
  [ "${UNCORDEX_PKG_REQUIRE_NOTARIZED:-0}" = 1 ] && VALIDATE_ARGS+=(--require-notarized)
  if UNCORDEX_PKG_VERIFY_ROOT="$TEST_ROOT/artifact-verify" "$ROOT_DIR/packaging/validate.sh" "$PACKAGE" "${VALIDATE_ARGS[@]}"; then
    passed=$((passed + 1)); /usr/bin/printf 'ok - built package validates\n'
  else
    failed=$((failed + 1)); /usr/bin/printf 'not ok - built package validates\n'
  fi
fi

/usr/bin/printf '%s tests passed; %s tests failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
