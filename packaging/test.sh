#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="${UNCORDEX_PKG_TEST_ROOT:-$HOME/dev/build/uncordex/pkg-tests}"
case "$TEST_ROOT" in "$HOME/dev/build"|"$HOME/dev/build"/*) ;; *) /usr/bin/printf 'packaging/test.sh: test root must stay under %s\n' "$HOME/dev/build" >&2; exit 1 ;; esac
if [ -e "$TEST_ROOT" ]; then /usr/bin/find "$TEST_ROOT" -depth -delete; fi
/bin/mkdir -p "$TEST_ROOT"

passed=0
failed=0
check() {
  if "$@"; then passed=$((passed + 1)); /usr/bin/printf 'ok - %s\n' "$*"
  else failed=$((failed + 1)); /usr/bin/printf 'not ok - %s\n' "$*"
  fi
}

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
