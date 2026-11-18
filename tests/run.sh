#!/bin/bash
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT_DIR/tests/fixtures"
PASS_COUNT=0
FAIL_COUNT=0
TEST_ROOT="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/uncordex-tests.XXXXXX")"
trap '/bin/rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

fail() {
  printf 'not ok - %s\n' "$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

pass() {
  printf 'ok - %s\n' "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

assert_eq() {
  expected="$1"
  actual="$2"
  message="$3"
  if [ "$expected" = "$actual" ]; then
    pass "$message"
  else
    fail "$message (expected '$expected', got '$actual')"
  fi
}

assert_ne() {
  unexpected="$1"
  actual="$2"
  message="$3"
  if [ "$unexpected" != "$actual" ]; then
    pass "$message"
  else
    fail "$message (both were '$actual')"
  fi
}

assert_contains() {
  needle="$1"
  haystack="$2"
  message="$3"
  case "$haystack" in
    *"$needle"*) pass "$message" ;;
    *) fail "$message (missing '$needle')" ;;
  esac
}

reset_snapshots() {
  UNCORDEX_THUNDERBOLT_SNAPSHOT="$FIXTURES/empty.plist"
  UNCORDEX_USB_SNAPSHOT="$FIXTURES/empty.plist"
  UNCORDEX_ADAPTER_SNAPSHOT="$FIXTURES/empty.plist"
  export UNCORDEX_THUNDERBOLT_SNAPSHOT UNCORDEX_USB_SNAPSHOT UNCORDEX_ADAPTER_SNAPSHOT
}

if [ ! -r "$ROOT_DIR/lib/source.sh" ]; then
  printf 'not ok - production source library is missing\n'
  exit 1
fi

# shellcheck disable=SC1091
. "$ROOT_DIR/lib/source.sh"

reset_snapshots
large_key_a="$(source_key thunderbolt -8123456789012345678)"
large_key_b="$(source_key thunderbolt -8123456789012345677)"
assert_ne "$large_key_a" "$large_key_b" "large Thunderbolt UIDs remain distinct"

UNCORDEX_THUNDERBOLT_SNAPSHOT="$FIXTURES/thunderbolt-dock.plist"
discover_sources
assert_eq "1" "${#SOURCE_KEYS[@]}" "host Thunderbolt controllers are excluded"
assert_eq "thunderbolt" "${SOURCE_KINDS[0]:-}" "external Thunderbolt source is classified"
assert_eq "Example Vendor Desk Dock" "${SOURCE_LABELS[0]:-}" "Thunderbolt source has a useful label"
dock_key="${SOURCE_KEYS[0]:-}"

UNCORDEX_THUNDERBOLT_SNAPSHOT="$FIXTURES/thunderbolt-dock-other-port.plist"
assert_eq "match" "$(source_presence thunderbolt "$dock_key")" "same dock matches after a port change"

UNCORDEX_THUNDERBOLT_SNAPSHOT="$FIXTURES/thunderbolt-other.plist"
assert_eq "absent" "$(source_presence thunderbolt "$dock_key")" "different Thunderbolt UID is rejected"

UNCORDEX_THUNDERBOLT_SNAPSHOT="$FIXTURES/thunderbolt-duplicate.plist"
assert_eq "unknown" "$(source_presence thunderbolt "$(source_key thunderbolt 777)")" "duplicate Thunderbolt identities fail closed"

UNCORDEX_THUNDERBOLT_SNAPSHOT="$FIXTURES/malformed.plist"
assert_eq "unknown" "$(source_presence thunderbolt "$dock_key")" "malformed hardware data is unknown"

reset_snapshots
UNCORDEX_ADAPTER_SNAPSHOT="$FIXTURES/adapter-serialized.plist"
discover_sources
assert_eq "1" "${#SOURCE_KEYS[@]}" "serialized charger is discoverable"
assert_eq "adapter" "${SOURCE_KINDS[0]:-}" "serialized charger is classified"
adapter_key="${SOURCE_KEYS[0]:-}"

UNCORDEX_ADAPTER_SNAPSHOT="$FIXTURES/adapter-serialized-other-power.plist"
assert_eq "match" "$(source_presence adapter "$adapter_key")" "same charger matches after negotiated power changes"

UNCORDEX_ADAPTER_SNAPSHOT="$FIXTURES/adapter-other.plist"
assert_eq "absent" "$(source_presence adapter "$adapter_key")" "same-model charger with another serial is rejected"

UNCORDEX_ADAPTER_SNAPSHOT="$FIXTURES/adapter-generic.plist"
discover_sources
assert_eq "0" "${#SOURCE_KEYS[@]}" "charger without a serial is not treated as exact"

UNCORDEX_ADAPTER_SNAPSHOT="$FIXTURES/adapter-zero.plist"
discover_sources
assert_eq "0" "${#SOURCE_KEYS[@]}" "all-zero charger serial is rejected as a placeholder"

reset_snapshots
UNCORDEX_USB_SNAPSHOT="$FIXTURES/usb-hub.plist"
discover_sources
assert_eq "1" "${#SOURCE_KEYS[@]}" "only a serialized USB hub is offered"
assert_eq "usb" "${SOURCE_KINDS[0]:-}" "USB hub is classified"

if ! /usr/bin/grep -q '^watcher_reset_runtime()' "$ROOT_DIR/watch-power"; then
  fail "watcher state machine is available for simulation"
else
  UNCORDEX_WATCHER_LIBRARY_ONLY=1
  UNCORDEX_SIMULATED_CLOCK=1
  export UNCORDEX_WATCHER_LIBRARY_ONLY UNCORDEX_SIMULATED_CLOCK
  # shellcheck disable=SC1091,SC2034,SC2153
  . "$ROOT_DIR/watch-power"

  TRACE=""
  TEST_POWER=ac
  TEST_SOURCE=match
  TEST_CONNECTED=1
  TEST_CONNECT_SUCCEEDS_AT=1
  TEST_CONNECT_COUNT=0
  TEST_DISCONNECT_OK=1
  TEST_BLUETOOTH_OK=1
  TEST_SOURCE_AFTER_CONNECT=""

  read_power() { /usr/bin/printf '%s\n' "$TEST_POWER"; }
  read_saved_source() { /usr/bin/printf '%s\n' "$TEST_SOURCE"; }
  speaker_state() { /usr/bin/printf '%s\n' "$TEST_CONNECTED"; }
  bluetooth_available() { [ "$TEST_BLUETOOTH_OK" -eq 1 ]; }
  perform_disconnect() {
    TRACE="${TRACE}disconnect\n"
    if [ "$TEST_DISCONNECT_OK" -eq 1 ]; then TEST_CONNECTED=0; return 0; fi
    return 1
  }
  perform_connect() {
    TEST_CONNECT_COUNT=$((TEST_CONNECT_COUNT + 1))
    TRACE="${TRACE}connect:${TEST_CONNECT_COUNT}\n"
    if [ -n "${TEST_SOURCE_AFTER_CONNECT:-}" ]; then TEST_SOURCE="$TEST_SOURCE_AFTER_CONNECT"; fi
    if [ "$TEST_CONNECT_COUNT" -ge "$TEST_CONNECT_SUCCEEDS_AT" ]; then
      TEST_CONNECTED=1
      return 0
    fi
    return 1
  }

  watcher_fixture_reset() {
    RECONNECT_MODE=source
    SOURCE_KIND=thunderbolt
    SOURCE_KEY=test-key
    SOURCE_LABEL="Test dock"
    DEVICE_MAC=AA-BB-CC-DD-EE-FF
    BOOT_ID=test-boot
    STATE_BINDING=test-binding
    STATE_FILE="$TEST_ROOT/state"
    TRACE=""
    TEST_POWER=ac
    TEST_SOURCE=match
    TEST_CONNECTED=1
    TEST_CONNECT_SUCCEEDS_AT=1
    TEST_CONNECT_COUNT=0
    TEST_DISCONNECT_OK=1
    TEST_BLUETOOTH_OK=1
    TEST_SOURCE_AFTER_CONNECT=""
    watcher_reset_runtime
  }

  watcher_fixture_reset
  watcher_tick 0
  watcher_tick 1
  TEST_POWER=battery
  watcher_tick 2
  assert_eq "pending" "$PHASE" "owned battery departure creates pending restore"
  assert_contains "disconnect" "$TRACE" "connected speaker is disconnected on battery"

  TEST_POWER=ac
  TEST_SOURCE=absent
  watcher_tick 3
  watcher_tick 4
  assert_eq "0" "$TEST_CONNECT_COUNT" "unrelated charger cannot restore the speaker"
  assert_eq "pending" "$PHASE" "wrong charger preserves pending restore"

  TEST_SOURCE=match
  watcher_tick 5
  watcher_tick 6
  assert_eq "1" "$TEST_CONNECT_COUNT" "saved dock returning on existing AC restores speaker"
  assert_eq "idle" "$PHASE" "successful restore consumes permission"
  TEST_CONNECTED=0
  watcher_tick 7
  assert_eq "1" "$TEST_CONNECT_COUNT" "manual disconnect after restore is respected"

  watcher_fixture_reset
  TEST_CONNECT_SUCCEEDS_AT=4
  watcher_tick 0
  watcher_tick 1
  TEST_POWER=battery
  watcher_tick 2
  TEST_POWER=ac
  watcher_tick 3
  watcher_tick 4
  watcher_tick 9
  watcher_tick 19
  watcher_tick 39
  assert_eq "4" "$TEST_CONNECT_COUNT" "a fourth scheduled attempt can succeed"
  assert_eq "idle" "$PHASE" "later successful retry consumes permission"

  watcher_fixture_reset
  watcher_tick 0
  watcher_tick 1
  TEST_SOURCE=absent
  watcher_tick 2
  TEST_SOURCE=match
  watcher_tick 3
  assert_eq "idle" "$PHASE" "one missing-device sample does not create departure"
  assert_eq "" "$TRACE" "debounced source noise takes no Bluetooth action"

  watcher_fixture_reset
  watcher_tick 0
  watcher_tick 1
  TEST_SOURCE=absent
  watcher_tick 2
  watcher_tick 3
  assert_eq "pending" "$PHASE" "dock removal on uninterrupted AC owns a restore"
  TEST_CONNECTED=1
  watcher_tick 4
  assert_eq "idle" "$PHASE" "manual connection consumes pending permission"

  watcher_fixture_reset
  TEST_CONNECTED=0
  watcher_tick 0
  watcher_tick 1
  TEST_POWER=battery
  watcher_tick 2
  TEST_POWER=ac
  watcher_tick 3
  assert_eq "" "$TRACE" "already-disconnected speaker creates no owned action"
  assert_eq "idle" "$PHASE" "already-disconnected departure creates no restore permission"

  watcher_fixture_reset
  TEST_DISCONNECT_OK=0
  watcher_tick 0
  watcher_tick 1
  TEST_POWER=battery
  watcher_tick 2
  assert_eq "idle" "$PHASE" "failed disconnect creates no restore permission"

  watcher_fixture_reset
  TEST_SOURCE=absent
  watcher_tick 0
  watcher_tick 1
  TEST_POWER=battery
  watcher_tick 2
  assert_contains "disconnect" "$TRACE" "battery departure still disconnects in an unrelated source context"
  assert_eq "idle" "$PHASE" "unrelated source context grants no exact-source restore"

  watcher_fixture_reset
  TEST_CONNECT_SUCCEEDS_AT=99
  watcher_tick 0
  watcher_tick 1
  TEST_POWER=battery
  watcher_tick 2
  TEST_POWER=ac
  watcher_tick 3
  watcher_tick 4
  watcher_tick 9
  watcher_tick 19
  watcher_tick 39
  watcher_tick 79
  watcher_tick 139
  assert_eq "6" "$TEST_CONNECT_COUNT" "return episode is bounded to six attempts"
  assert_eq "paused" "$PHASE" "exhausted retries pause automatic restoration"

  watcher_fixture_reset
  TEST_CONNECT_SUCCEEDS_AT=99
  watcher_tick 0
  watcher_tick 1
  TEST_POWER=battery
  watcher_tick 2
  TEST_POWER=ac
  watcher_tick 3
  assert_eq "1" "$ATTEMPTS" "unknown-sample scenario begins with one used attempt"
  TEST_SOURCE=unknown
  watcher_tick 4
  watcher_tick 5
  assert_eq "1" "$ATTEMPTS" "unknown source samples neither attempt nor reset the budget"
  TEST_SOURCE=match
  watcher_tick 6
  watcher_tick 7
  watcher_tick 8
  assert_eq "2" "$ATTEMPTS" "retry resumes after two fresh valid source samples"

  watcher_fixture_reset
  TEST_CONNECT_SUCCEEDS_AT=99
  watcher_tick 0
  watcher_tick 1
  TEST_POWER=battery
  watcher_tick 2
  TEST_POWER=ac
  watcher_tick 3
  assert_eq "1" "$ATTEMPTS" "fresh-source regression begins with one failed attempt"
  NEXT_ATTEMPT=6
  TEST_SOURCE=unknown
  watcher_tick 4
  watcher_tick 5
  TEST_SOURCE=match
  watcher_tick 6
  assert_eq "1" "$ATTEMPTS" "one recovered source sample cannot use a stale match"
  watcher_tick 7
  assert_eq "2" "$ATTEMPTS" "two recovered source samples permit a due retry"

  watcher_fixture_reset
  TEST_BLUETOOTH_OK=0
  watcher_tick 0
  watcher_tick 1
  TEST_POWER=battery
  watcher_tick 2
  TEST_POWER=ac
  watcher_tick 3
  watcher_tick 4
  assert_eq "0" "$TEST_CONNECT_COUNT" "Bluetooth-off state issues no connect command"

  watcher_fixture_reset
  RECONNECT_MODE=any_power
  watcher_tick 0
  TEST_POWER=battery
  watcher_tick 1
  TEST_POWER=ac
  watcher_tick 2
  assert_eq "1" "$TEST_CONNECT_COUNT" "explicit any-power mode restores on an AC return"

  watcher_fixture_reset
  RECONNECT_MODE=disconnect_only
  watcher_tick 0
  TEST_POWER=battery
  watcher_tick 1
  TEST_POWER=ac
  watcher_tick 2
  assert_contains "disconnect" "$TRACE" "disconnect-only mode still disconnects on battery"
  assert_eq "0" "$TEST_CONNECT_COUNT" "disconnect-only mode never reconnects"

  watcher_fixture_reset
  TEST_CONNECT_SUCCEEDS_AT=99
  watcher_tick 0
  watcher_tick 1
  TEST_POWER=battery
  watcher_tick 2
  TEST_POWER=ac
  watcher_tick 3
  assert_eq "1" "$ATTEMPTS" "first failed attempt is persisted"
  watcher_reset_runtime
  load_state
  assert_eq "pending" "$PHASE" "same-boot restart retains pending ownership"
  assert_eq "1" "$ATTEMPTS" "same-boot restart retains retry usage"
  watcher_tick 9
  assert_eq "1" "$TEST_CONNECT_COUNT" "restart requires a fresh source baseline before retry"
  watcher_tick 10
  assert_eq "2" "$TEST_CONNECT_COUNT" "retry resumes after fresh revalidation"

  /usr/bin/printf '%s\n' 'schema=1' 'boot=wrong-boot' 'binding=test-binding' 'phase=pending' 'attempts=0' 'next_attempt=0' 'window_deadline=0' 'last_power=ac' 'last_source=match' 'departure_observed=1' >"$STATE_FILE"
  if load_state; then fail "different-boot state is rejected"
  else pass "different-boot state is rejected"; fi
  assert_eq "idle" "$PHASE" "rejected state carries no restore ownership"

  /usr/bin/printf '%s\n' 'not valid state' >"$STATE_FILE"
  if load_state; then fail "malformed runtime state is rejected"
  else pass "malformed runtime state is rejected"; fi

  /usr/bin/printf '%s\n' 'schema=1' 'boot=test-boot' 'binding=test-binding' 'phase=disconnecting' 'attempts=0' 'next_attempt=0' 'window_deadline=0' 'last_power=battery' 'last_source=match' 'departure_observed=0' >"$STATE_FILE"
  load_state
  assert_eq "idle" "$PHASE" "interrupted disconnect never becomes restore permission"

  watcher_fixture_reset
  watcher_tick 0
  watcher_tick 1
  save_state
  TRACE=""
  watcher_reset_runtime
  load_state
  TEST_POWER=battery
  watcher_tick 2
  assert_eq "" "$TRACE" "restart never infers an unseen power departure"
  assert_eq "idle" "$PHASE" "restart establishes a baseline without new permission"

  watcher_fixture_reset
  TEST_SOURCE_AFTER_CONNECT=absent
  watcher_tick 0
  watcher_tick 1
  TEST_POWER=battery
  watcher_tick 2
  TEST_POWER=ac
  watcher_tick 3
  assert_contains "connect:1" "$TRACE" "eligible return starts one connect operation"
  assert_eq "pending" "$PHASE" "source loss during connect stops retries until another return"
  assert_eq "1" "$DEPARTURE_OBSERVED" "verified rollback records the new departure"

  watcher_fixture_reset
  TEST_CONNECT_SUCCEEDS_AT=99
  TEST_SOURCE_AFTER_CONNECT=unknown
  watcher_tick 0
  watcher_tick 1
  TEST_POWER=battery
  watcher_tick 2
  TEST_POWER=ac
  watcher_tick 3
  assert_eq "1" "$ATTEMPTS" "unknown post-connect source keeps a failed attempt charged"
  assert_eq "0" "$DEPARTURE_OBSERVED" "unknown post-connect source does not invent a departure"
  assert_ne "0" "$WINDOW_DEADLINE" "unknown post-connect source keeps the existing retry window"
  TEST_SOURCE=match
  watcher_tick 4
  watcher_tick 5
  watcher_tick 8
  assert_eq "2" "$ATTEMPTS" "a recovered source continues the existing retry budget"

  watcher_fixture_reset
  TEST_SOURCE_AFTER_CONNECT=unknown
  watcher_tick 0
  watcher_tick 1
  TEST_POWER=battery
  watcher_tick 2
  TEST_POWER=ac
  watcher_tick 3
  assert_eq "1" "$ATTEMPTS" "unknown post-connect source keeps a successful attempt charged"
  assert_eq "0" "$DEPARTURE_OBSERVED" "unknown after a successful connect does not invent a departure"
  assert_ne "0" "$WINDOW_DEADLINE" "unknown after a successful connect keeps the retry window"
  assert_eq "0" "$TEST_CONNECTED" "unknown after a successful connect rolls back the watcher connection"

  watcher_fixture_reset
  TEST_CONNECT_SUCCEEDS_AT=99
  watcher_tick 0
  watcher_tick 1
  TEST_POWER=battery
  watcher_tick 2
  TEST_POWER=ac
  watcher_tick 3
  watcher_tick 9
  watcher_tick 19
  watcher_tick 39
  watcher_tick 79
  watcher_tick 139
  TEST_SOURCE=absent
  watcher_tick 140
  watcher_tick 141
  TEST_SOURCE=match
  watcher_tick 142
  watcher_tick 143
  assert_eq "7" "$TEST_CONNECT_COUNT" "a genuine depart-return cycle reopens an exhausted budget"
fi

make_fake_install_tools() {
  FAKE_BLUEUTIL="$TEST_ROOT/fake-blueutil"
  FAKE_LAUNCHCTL="$TEST_ROOT/fake-launchctl"
  # The quoted expressions belong to the generated fake, not this process.
  # shellcheck disable=SC2016
  /usr/bin/printf '%s\n' \
    '#!/bin/bash' \
    'case "${1:-}" in' \
    '  --paired) printf "%s\\n" "address: aa-bb-cc-dd-ee-ff, not connected, not favourite, paired, name: \"Test Speaker\", recent access date: 2026-01-01" "address: 11-22-33-44-55-66, connected (master, -50 dBm), not favourite, paired, name: \"Test Keyboard\", recent access date: 2026-01-01" ;;' \
    '  --is-connected) printf "0\\n" ;;' \
    'esac' \
    'exit 0' >"$FAKE_BLUEUTIL"
  # shellcheck disable=SC2016
  /usr/bin/printf '%s\n' \
    '#!/bin/bash' \
    'printf "%s\\n" "$*" >> "${UNCORDEX_LAUNCH_TRACE:?}"' \
    'if [ "${1:-}" = print ]; then' \
    '  case "${2:-}" in *com.bolyki.bt-auto-speaker-power) [ "${UNCORDEX_BT_AUTO_LEGACY_SERVICE_PRESENT:-0}" = 1 ] && exit 0 ;; *com.unplugged-speaker.watch-power) [ "${UNCORDEX_UNPLUGGED_LEGACY_SERVICE_PRESENT:-0}" = 1 ] && exit 0 ;; *uk.magrathean.uncordex.watch-power) [ "${UNCORDEX_CANONICAL_LOADED:-0}" = 1 ] && exit 0 ;; esac' \
    '  exit 1' \
    'fi' \
    'if [ "${1:-}" = bootout ] && [ "${UNCORDEX_FAIL_BOOTOUT:-0}" = 1 ]; then exit 1; fi' \
    'if [ "${1:-}" = bootstrap ] && [ "${UNCORDEX_FAIL_BOOTSTRAP_ONCE:-0}" = 1 ] && [ ! -e "${UNCORDEX_LAUNCH_TRACE}.failed-once" ]; then touch "${UNCORDEX_LAUNCH_TRACE}.failed-once"; exit 1; fi' \
    'exit 0' >"$FAKE_LAUNCHCTL"
  /bin/chmod 755 "$FAKE_BLUEUTIL" "$FAKE_LAUNCHCTL"
}

# run_cli CASE [uncordex arguments...]: run the CLI against isolated paths only.
run_cli() {
  install_case="$1"
  shift
  INSTALL_BASE="$TEST_ROOT/$install_case"
  UNCORDEX_THUNDERBOLT_SNAPSHOT="${TEST_THUNDERBOLT_SNAPSHOT:-$FIXTURES/thunderbolt-dock.plist}" \
  UNCORDEX_USB_SNAPSHOT="${TEST_USB_SNAPSHOT:-$FIXTURES/empty.plist}" \
  UNCORDEX_ADAPTER_SNAPSHOT="${TEST_ADAPTER_SNAPSHOT:-$FIXTURES/empty.plist}" \
  UNCORDEX_APP_DIR="$INSTALL_BASE/app" \
  UNCORDEX_BIN_DIR="$INSTALL_BASE/bin" \
  UNCORDEX_CONFIG_DIR="$INSTALL_BASE/config" \
  UNCORDEX_STATE_DIR="$INSTALL_BASE/state" \
  UNCORDEX_PLIST="$INSTALL_BASE/LaunchAgents/service.plist" \
  UNCORDEX_LOG_DIR="$INSTALL_BASE/logs" \
  UNCORDEX_BLUEUTIL="$FAKE_BLUEUTIL" \
  UNCORDEX_LAUNCHCTL="$FAKE_LAUNCHCTL" \
  UNCORDEX_LAUNCH_TRACE="$INSTALL_BASE/launch.trace" \
  "${UNCORDEX_CLI:-$ROOT_DIR/uncordex}" "$@"
}

run_installer() {
  setup_case="$1"
  shift
  run_cli "$setup_case" setup "$@"
}

make_fake_install_tools

help_output="$("$ROOT_DIR/uncordex" help 2>&1)"
assert_contains "uncordex setup" "$help_output" "help names the setup command"
unknown_output="$("$ROOT_DIR/uncordex" frobnicate 2>&1)"
unknown_status=$?
assert_ne "0" "$unknown_status" "an unknown command fails"
assert_contains "uncordex help" "$unknown_output" "an unknown command says what to run next"

status_missing_output="$(run_cli status-missing status 2>&1)"
assert_contains "not set up" "$status_missing_output" "status explains a missing setup"
assert_contains "uncordex setup" "$status_missing_output" "status points to setup"
if [ ! -e "$TEST_ROOT/status-missing/config" ] && [ ! -e "$TEST_ROOT/status-missing/state" ]; then pass "status is read-only"
else fail "status is read-only"; fi

status_valid_base="$TEST_ROOT/status-valid"
/bin/mkdir -p "$status_valid_base/config"
/usr/bin/printf '%s\n' \
  'CONFIG_VERSION=1' \
  'DEVICE_MAC=AA-BB-CC-DD-EE-FF' \
  "BLUEUTIL=$FAKE_BLUEUTIL" \
  'RECONNECT_MODE=source' \
  'SOURCE_KIND=thunderbolt' \
  "SOURCE_KEY=$dock_key" \
  'SOURCE_LABEL=Test\ Dock' >"$status_valid_base/config/config"
status_valid_output="$(run_cli status-valid 2>&1)"
assert_contains "Test Dock" "$status_valid_output" "bare uncordex shows the saved rule"
assert_contains "Dock:    attached" "$status_valid_output" "status reports the current dock reading"
assert_contains "Service: not installed" "$status_valid_output" "status reports the service state"

devices_output="$(run_cli devices devices 2>&1)"
assert_contains " 1) Test Speaker" "$devices_output" "devices lists paired devices by number"

sources_output="$(run_cli sources sources 2>&1)"
sources_status=$?
assert_eq "0" "$sources_status" "read-only source discovery succeeds"
assert_contains "Example Vendor Desk Dock" "$sources_output" "sources lists the usable dock"
if [ ! -e "$TEST_ROOT/sources" ]; then pass "sources creates no files"
else fail "sources creates no files"; fi

TEST_THUNDERBOLT_SNAPSHOT="$FIXTURES/malformed.plist"
export TEST_THUNDERBOLT_SNAPSHOT
discovery_failure_output="$(run_cli discovery-failure sources 2>&1)"
discovery_failure_status=$?
unset TEST_THUNDERBOLT_SNAPSHOT
assert_ne "0" "$discovery_failure_status" "hardware discovery failure is reported"
assert_contains "could not read connected hardware" "$discovery_failure_output" "discovery failure is explicit"

UNCORDEX_FORCE_INTERACTIVE=1
export UNCORDEX_FORCE_INTERACTIVE
cancel_output="$(/usr/bin/printf 'q\n' | run_installer cancel AA-BB-CC-DD-EE-FF 2>&1)"
cancel_status=$?
assert_ne "0" "$cancel_status" "guided setup can be cancelled"
assert_contains "setup cancelled" "$cancel_output" "cancellation leaves a clear result"
if [ ! -e "$TEST_ROOT/cancel" ]; then pass "cancelled setup leaves installation paths untouched"
else fail "cancelled setup leaves installation paths untouched"; fi

single_output="$(/usr/bin/printf '\n' | run_installer guided-single AA-BB-CC-DD-EE-FF --dry-run 2>&1)"
single_status=$?
assert_eq "0" "$single_status" "guided setup recommends the sole exact source"
assert_contains "Example Vendor Desk Dock" "$single_output" "guided setup previews the selected dock"

guided_speaker_output="$(/usr/bin/printf '1\nd\n' | run_installer guided-speaker --dry-run 2>&1)"
guided_speaker_status=$?
assert_eq "0" "$guided_speaker_status" "guided setup picks a speaker by number"
assert_contains "Test Speaker (aa-bb-cc-dd-ee-ff)" "$guided_speaker_output" "guided speaker choice is previewed by name"

confirm_output="$(/usr/bin/printf 'n\n' | run_installer confirm-no AA-BB-CC-DD-EE-FF --any-power 2>&1)"
confirm_status=$?
assert_ne "0" "$confirm_status" "declining the confirmation stops setup"
if [ ! -e "$TEST_ROOT/confirm-no/config/config" ]; then pass "declined setup writes no configuration"
else fail "declined setup writes no configuration"; fi

TEST_USB_SNAPSHOT="$FIXTURES/usb-hub.plist"
export TEST_USB_SNAPSHOT
multiple_output="$(/usr/bin/printf '2\n' | run_installer guided-multiple AA-BB-CC-DD-EE-FF --dry-run 2>&1)"
multiple_status=$?
numbered_source_output="$(run_installer numbered-source AA-BB-CC-DD-EE-FF --source 2 --dry-run </dev/null 2>&1)"
numbered_source_status=$?
unset TEST_USB_SNAPSHOT UNCORDEX_FORCE_INTERACTIVE
assert_eq "0" "$multiple_status" "guided setup accepts a choice among multiple sources"
assert_contains "Desk USB-C Hub" "$multiple_output" "guided setup previews the chosen source"
assert_eq "0" "$numbered_source_status" "--source accepts the number from 'uncordex sources'"
assert_contains "Desk USB-C Hub" "$numbered_source_output" "numbered source resolves to the listed dock"

numbered_speaker_output="$(run_installer numbered-speaker 1 --any-power --dry-run 2>&1)"
numbered_speaker_status=$?
assert_eq "0" "$numbered_speaker_status" "setup accepts a speaker number"
assert_contains "Test Speaker (aa-bb-cc-dd-ee-ff)" "$numbered_speaker_output" "speaker number resolves to the paired device"

dry_output="$(run_installer dry AA-BB-CC-DD-EE-FF --any-power --dry-run 2>&1)"
dry_status=$?
assert_eq "0" "$dry_status" "explicit any-power dry-run validates"
assert_contains "on external power" "$dry_output" "dry-run previews broad matching clearly"
assert_contains "nothing was changed" "$dry_output" "dry-run says nothing changed"
if [ ! -e "$TEST_ROOT/dry" ]; then pass "dry-run leaves installation paths untouched"
else fail "dry-run leaves installation paths untouched"; fi

conflict_output="$(run_installer conflict AA-BB-CC-DD-EE-FF --any-power --disconnect-only --dry-run 2>&1)"
conflict_status=$?
assert_ne "0" "$conflict_status" "conflicting mode flags fail"
assert_contains "choose only one rule" "$conflict_output" "mode conflict explains the correction"

duplicate_source_output="$(run_installer duplicate-source AA-BB-CC-DD-EE-FF --source "$dock_key" --source "$dock_key" --dry-run 2>&1)"
duplicate_source_status=$?
assert_ne "0" "$duplicate_source_status" "repeated source mode fails"
assert_contains "choose only one rule" "$duplicate_source_output" "repeated source mode explains the correction"

missing_output="$(run_installer missing AA-BB-CC-DD-EE-FF --dry-run 2>&1)"
missing_status=$?
assert_ne "0" "$missing_status" "first noninteractive setup requires a deliberate rule"
assert_contains "--source N, --any-power or --disconnect-only" "$missing_output" "missing-rule error lists explicit choices"

invalid_output="$(run_installer invalid AA-BB-CC-DD-EE-FF --source deadbeef --dry-run 2>&1)"
invalid_status=$?
assert_ne "0" "$invalid_status" "unknown source keys are rejected"
assert_contains "is not connected now" "$invalid_output" "invalid source error fails closed"

bad_address_output="$(run_installer bad-address not-an-address --any-power --dry-run 2>&1)"
assert_contains "AA-BB-CC-DD-EE-FF" "$bad_address_output" "an invalid speaker shows the expected format"

FAILING_PLUTIL="$TEST_ROOT/failing-plutil"
# The quoted expressions belong to the generated fake, not this process.
# shellcheck disable=SC2016
/usr/bin/printf '%s\n' \
  '#!/bin/bash' \
  'if [ "${1:-}" = -help ]; then echo "-extract"; exit 0; fi' \
  'if [ "${1:-}" = -insert ]; then exit 7; fi' \
  'exec /usr/bin/plutil "$@"' >"$FAILING_PLUTIL"
/bin/chmod 755 "$FAILING_PLUTIL"
UNCORDEX_PLUTIL="$FAILING_PLUTIL"
export UNCORDEX_PLUTIL
staging_output="$(run_installer staging-failure AA-BB-CC-DD-EE-FF --any-power 2>&1)"
staging_status=$?
unset UNCORDEX_PLUTIL
assert_ne "0" "$staging_status" "staging validation failure is reported"
case "$staging_output" in *"Uncordex is running"*) fail "staging failure never reports success" ;; *) pass "staging failure never reports success" ;; esac
if [ ! -e "$TEST_ROOT/staging-failure" ]; then pass "staging failure leaves existing service paths untouched"
else fail "staging failure leaves existing service paths untouched"; fi

mkdir_failure_base="$TEST_ROOT/mkdir-failure"
/bin/mkdir -p "$mkdir_failure_base/config"
/usr/bin/printf '%s\n' 'existing config' >"$mkdir_failure_base/config/config"
/usr/bin/printf '%s\n' 'not a directory' >"$mkdir_failure_base/app"
UNCORDEX_CANONICAL_LOADED=1
export UNCORDEX_CANONICAL_LOADED
if run_installer mkdir-failure AA-BB-CC-DD-EE-FF --any-power >"$mkdir_failure_base/output" 2>&1; then
  mkdir_failure_status=0
else
  mkdir_failure_status=$?
fi
unset UNCORDEX_CANONICAL_LOADED
assert_ne "0" "$mkdir_failure_status" "directory preparation failure is reported"
assert_eq "existing config" "$(/bin/cat "$mkdir_failure_base/config/config")" "directory preparation failure preserves existing files"
mkdir_failure_trace="$(/bin/cat "$mkdir_failure_base/launch.trace" 2>/dev/null || true)"
case "$mkdir_failure_trace" in *"bootout "*) fail "directory preparation failure does not stop the loaded service" ;; *) pass "directory preparation failure does not stop the loaded service" ;; esac

bootout_failure_base="$TEST_ROOT/bootout-failure"
/bin/mkdir -p "$bootout_failure_base/app/lib" "$bootout_failure_base/config" "$bootout_failure_base/LaunchAgents"
/usr/bin/printf '%s\n' old-watcher >"$bootout_failure_base/app/watch-power"
/usr/bin/printf '%s\n' old-library >"$bootout_failure_base/app/lib/source.sh"
/usr/bin/printf '%s\n' '# old-config' >"$bootout_failure_base/config/config"
/usr/bin/printf '%s\n' old-plist >"$bootout_failure_base/LaunchAgents/service.plist"
bootout_failure_output="$(UNCORDEX_CANONICAL_LOADED=1 UNCORDEX_FAIL_BOOTOUT=1 run_installer bootout-failure AA-BB-CC-DD-EE-FF --any-power 2>&1)"
bootout_failure_status=$?
assert_ne "0" "$bootout_failure_status" "loaded-service stop failure blocks setup"
assert_contains "could not be stopped" "$bootout_failure_output" "loaded-service stop failure is explicit"
assert_eq "old-watcher" "$(/bin/cat "$bootout_failure_base/app/watch-power")" "loaded-service stop failure preserves watcher"
assert_eq "old-library" "$(/bin/cat "$bootout_failure_base/app/lib/source.sh")" "loaded-service stop failure preserves source library"
assert_eq "# old-config" "$(/bin/cat "$bootout_failure_base/config/config")" "loaded-service stop failure preserves configuration"
assert_eq "old-plist" "$(/bin/cat "$bootout_failure_base/LaunchAgents/service.plist")" "loaded-service stop failure preserves LaunchAgent"
bootout_failure_trace="$(/bin/cat "$bootout_failure_base/launch.trace")"
assert_contains "bootout gui/" "$bootout_failure_trace" "loaded-service stop failure attempts canonical bootout"
case "$bootout_failure_trace" in *"bootstrap "*) fail "loaded-service stop failure does not bootstrap a replacement" ;; *) pass "loaded-service stop failure does not bootstrap a replacement" ;; esac

preserve_base="$TEST_ROOT/preserve"
/bin/mkdir -p "$preserve_base/config"
/usr/bin/printf '%s\n' \
  'CONFIG_VERSION=1' \
  'DEVICE_MAC=AA-BB-CC-DD-EE-FF' \
  "BLUEUTIL=$FAKE_BLUEUTIL" \
  'RECONNECT_MODE=source' \
  'SOURCE_KIND=thunderbolt' \
  "SOURCE_KEY=$dock_key" \
  'SOURCE_LABEL=Saved\ Dock' >"$preserve_base/config/config"
preserve_output="$(run_installer preserve --dry-run 2>&1)"
preserve_status=$?
assert_eq "0" "$preserve_status" "setup can keep an existing speaker and exact-source rule"
assert_contains "Saved Dock" "$preserve_output" "kept rule is shown in the preview"

success_output="$(run_installer success AA-BB-CC-DD-EE-FF --any-power 2>&1)"
success_status=$?
assert_eq "0" "$success_status" "isolated setup activates successfully"
assert_contains "Uncordex is running" "$success_output" "successful setup says it is running"
if [ -x "$TEST_ROOT/success/app/watch-power" ] && [ -r "$TEST_ROOT/success/app/lib/source.sh" ]; then pass "setup installs watcher and source library"
else fail "setup installs watcher and source library"; fi
assert_contains "RECONNECT_MODE=any_power" "$(/bin/cat "$TEST_ROOT/success/config/config")" "saved configuration records the explicit rule"
assert_contains "enable gui/" "$(/bin/cat "$TEST_ROOT/success/launch.trace")" "setup clears an earlier stop before starting"
if /usr/bin/plutil -lint "$TEST_ROOT/success/LaunchAgents/service.plist" >/dev/null; then pass "installed LaunchAgent is a valid plist"
else fail "installed LaunchAgent is a valid plist"; fi
status_state="$TEST_ROOT/status-only/runtime-state"
status_output="$(UNCORDEX_WATCHER_LIBRARY_ONLY=0 UNCORDEX_CONFIG_FILE="$TEST_ROOT/success/config/config" UNCORDEX_STATE_FILE="$status_state" "$TEST_ROOT/success/app/watch-power" --status 2>&1)"
status_status=$?
assert_eq "0" "$status_status" "installed watcher status is readable"
assert_contains "mode: any_power" "$status_output" "watcher status reports the configured rule"
if [ ! -e "$status_state" ]; then pass "status does not create runtime state"
else fail "status does not create runtime state"; fi
cli_status_output="$(UNCORDEX_CANONICAL_LOADED=1 run_cli success status 2>&1)"
assert_contains "Restore: no watcher-owned restore is pending" "$cli_status_output" "CLI status includes the watcher's restore state"

stop_output="$(UNCORDEX_CANONICAL_LOADED=1 run_cli success stop 2>&1)"
assert_contains "uncordex start" "$stop_output" "stop says how to turn it back on"
stop_trace="$(/bin/cat "$TEST_ROOT/success/launch.trace")"
assert_contains "disable gui/" "$stop_trace" "stop keeps the service off across logins"
start_output="$(run_cli success start 2>&1)"
start_status=$?
assert_eq "0" "$start_status" "start succeeds after stop"
assert_eq "2" "$(/usr/bin/grep -c '^bootstrap ' "$TEST_ROOT/success/launch.trace")" "start loads the LaunchAgent again"
not_setup_start_output="$(run_cli start-missing start 2>&1)"
assert_contains "uncordex setup" "$not_setup_start_output" "start without setup points to setup"

# Default application directory: XDG_DATA_HOME first, then $HOME/.local/share (an empty XDG_DATA_HOME counts as not set).
# HOME is a test directory here, and XDG_DATA_HOME is only ever assigned, never unset.
run_installer_default_app_dir() {
  install_case="$1"
  install_home="$2"
  install_xdg="$3"
  shift 3
  INSTALL_BASE="$TEST_ROOT/$install_case"
  (
    unset UNCORDEX_APP_DIR
    XDG_DATA_HOME="$install_xdg"
    export XDG_DATA_HOME
    HOME="$install_home" \
    UNCORDEX_THUNDERBOLT_SNAPSHOT="$FIXTURES/thunderbolt-dock.plist" \
    UNCORDEX_USB_SNAPSHOT="$FIXTURES/empty.plist" \
    UNCORDEX_ADAPTER_SNAPSHOT="$FIXTURES/empty.plist" \
    UNCORDEX_BIN_DIR="$INSTALL_BASE/bin" \
    UNCORDEX_CONFIG_DIR="$INSTALL_BASE/config" \
    UNCORDEX_STATE_DIR="$INSTALL_BASE/state" \
    UNCORDEX_PLIST="$INSTALL_BASE/LaunchAgents/service.plist" \
    UNCORDEX_LOG_DIR="$INSTALL_BASE/logs" \
    UNCORDEX_BLUEUTIL="$FAKE_BLUEUTIL" \
    UNCORDEX_LAUNCHCTL="$FAKE_LAUNCHCTL" \
    UNCORDEX_LAUNCH_TRACE="$INSTALL_BASE/launch.trace" \
    "$ROOT_DIR/uncordex" setup "$@"
  )
}

xdg_home="$TEST_ROOT/xdg-data-home-home"
xdg_data="$TEST_ROOT/xdg-data-home-data"
run_installer_default_app_dir xdg-data-home "$xdg_home" "$xdg_data" AA-BB-CC-DD-EE-FF --any-power >/dev/null 2>&1
xdg_status=$?
assert_eq "0" "$xdg_status" "setup with XDG_DATA_HOME succeeds"
if [ -x "$xdg_data/uncordex/watch-power" ] && [ -r "$xdg_data/uncordex/lib/source.sh" ]; then pass "XDG_DATA_HOME selects the default application directory"
else fail "XDG_DATA_HOME selects the default application directory"; fi
assert_eq "$xdg_data/uncordex/watch-power" "$(/usr/bin/plutil -extract ProgramArguments.0 raw -n "$TEST_ROOT/xdg-data-home/LaunchAgents/service.plist")" "LaunchAgent runs the watcher from XDG_DATA_HOME"
if [ ! -e "$xdg_home/.local" ]; then pass "XDG_DATA_HOME leaves the home data directory untouched"
else fail "XDG_DATA_HOME leaves the home data directory untouched"; fi

fallback_home="$TEST_ROOT/xdg-fallback-home"
run_installer_default_app_dir xdg-fallback "$fallback_home" "" AA-BB-CC-DD-EE-FF --any-power >/dev/null 2>&1
fallback_status=$?
assert_eq "0" "$fallback_status" "setup with an empty XDG_DATA_HOME succeeds"
if [ -x "$fallback_home/.local/share/uncordex/watch-power" ]; then pass "an empty XDG_DATA_HOME falls back to the home data directory"
else fail "an empty XDG_DATA_HOME falls back to the home data directory"; fi

UNCORDEX_UNPLUGGED_LEGACY_SERVICE_PRESENT=1
export UNCORDEX_UNPLUGGED_LEGACY_SERVICE_PRESENT
legacy_unplugged_output="$(run_installer legacy-unplugged AA-BB-CC-DD-EE-FF --any-power 2>&1)"
legacy_unplugged_status=$?
unset UNCORDEX_UNPLUGGED_LEGACY_SERVICE_PRESENT
assert_ne "0" "$legacy_unplugged_status" "prior public watcher blocks a competing setup"
assert_contains "com.unplugged-speaker.watch-power" "$legacy_unplugged_output" "prior public watcher identifies itself"
if [ ! -e "$TEST_ROOT/legacy-unplugged" ]; then pass "prior public watcher check occurs before persistent writes"
else fail "prior public watcher check occurs before persistent writes"; fi

UNCORDEX_BT_AUTO_LEGACY_SERVICE_PRESENT=1
export UNCORDEX_BT_AUTO_LEGACY_SERVICE_PRESENT
legacy_bt_auto_output="$(run_installer legacy-bt-auto AA-BB-CC-DD-EE-FF --any-power 2>&1)"
legacy_bt_auto_status=$?
unset UNCORDEX_BT_AUTO_LEGACY_SERVICE_PRESENT
assert_ne "0" "$legacy_bt_auto_status" "older watcher blocks a competing setup"
assert_contains "com.bolyki.bt-auto-speaker-power" "$legacy_bt_auto_output" "older watcher identifies itself"
if [ ! -e "$TEST_ROOT/legacy-bt-auto" ]; then pass "older watcher check occurs before persistent writes"
else fail "older watcher check occurs before persistent writes"; fi

rollback_base="$TEST_ROOT/rollback"
/bin/mkdir -p "$rollback_base/app/lib" "$rollback_base/config" "$rollback_base/LaunchAgents"
/usr/bin/printf '%s\n' old-watcher >"$rollback_base/app/watch-power"
/usr/bin/printf '%s\n' old-library >"$rollback_base/app/lib/source.sh"
/usr/bin/printf '%s\n' '# old-config' >"$rollback_base/config/config"
/usr/bin/printf '%s\n' old-plist >"$rollback_base/LaunchAgents/service.plist"
UNCORDEX_CANONICAL_LOADED=1
UNCORDEX_FAIL_BOOTSTRAP_ONCE=1
export UNCORDEX_CANONICAL_LOADED UNCORDEX_FAIL_BOOTSTRAP_ONCE
rollback_output="$(run_installer rollback AA-BB-CC-DD-EE-FF --any-power 2>&1)"
rollback_status=$?
unset UNCORDEX_CANONICAL_LOADED UNCORDEX_FAIL_BOOTSTRAP_ONCE
assert_ne "0" "$rollback_status" "activation failure is reported"
assert_contains "previous setup was restored" "$rollback_output" "rollback is reported clearly"
assert_eq "old-watcher" "$(/bin/cat "$rollback_base/app/watch-power")" "activation failure restores watcher"
assert_eq "old-library" "$(/bin/cat "$rollback_base/app/lib/source.sh")" "activation failure restores source library"
assert_eq "# old-config" "$(/bin/cat "$rollback_base/config/config")" "activation failure restores configuration"
assert_eq "old-plist" "$(/bin/cat "$rollback_base/LaunchAgents/service.plist")" "activation failure restores LaunchAgent"
assert_eq "2" "$(/usr/bin/grep -c '^bootstrap ' "$rollback_base/launch.trace")" "rollback reactivates a previously loaded service"

# install.sh from this checkout into isolated directories, then the installed command.
installer_base="$TEST_ROOT/installer"
installer_output="$(UNCORDEX_APP_DIR="$installer_base/app" UNCORDEX_BIN_DIR="$installer_base/bin" UNCORDEX_LAUNCHCTL="$FAKE_LAUNCHCTL" UNCORDEX_LAUNCH_TRACE="$installer_base/launch.trace" \
  "$ROOT_DIR/install.sh" --no-install-dependencies 2>&1)"
installer_status=$?
assert_eq "0" "$installer_status" "install.sh installs from a checkout"
assert_contains "uncordex setup" "$installer_output" "install.sh says what to run next"
assert_eq "uncordex $(/bin/cat "$ROOT_DIR/VERSION")" "$("$installer_base/bin/uncordex" version 2>&1)" "the linked command finds its installed files"
installed_setup_output="$(UNCORDEX_CLI="$installer_base/bin/uncordex" run_cli installed-setup setup AA-BB-CC-DD-EE-FF --any-power 2>&1)"
assert_contains "Uncordex is running" "$installed_setup_output" "the installed command completes setup"
installed_self_output="$(UNCORDEX_APP_DIR="$installer_base/app" UNCORDEX_BIN_DIR="$installer_base/bin" UNCORDEX_CONFIG_DIR="$installer_base/config" UNCORDEX_STATE_DIR="$installer_base/state" \
  UNCORDEX_PLIST="$installer_base/LaunchAgents/service.plist" UNCORDEX_LOG_DIR="$installer_base/logs" UNCORDEX_BLUEUTIL="$FAKE_BLUEUTIL" \
  UNCORDEX_LAUNCHCTL="$FAKE_LAUNCHCTL" UNCORDEX_LAUNCH_TRACE="$installer_base/launch.trace" "$installer_base/bin/uncordex" setup AA-BB-CC-DD-EE-FF --disconnect-only 2>&1)"
installed_self_status=$?
assert_eq "0" "$installed_self_status" "setup from the installed copy leaves its own files in place"
if /bin/bash -n "$installer_base/app/watch-power" && [ -s "$installer_base/app/lib/source.sh" ]; then pass "installed watcher survives setup from the installed copy"
else fail "installed watcher survives setup from the installed copy"; fi

uninstall_output="$(UNCORDEX_APP_DIR="$installer_base/app" UNCORDEX_BIN_DIR="$installer_base/bin" UNCORDEX_CONFIG_DIR="$installer_base/config" UNCORDEX_STATE_DIR="$installer_base/state" \
  UNCORDEX_PLIST="$installer_base/LaunchAgents/service.plist" UNCORDEX_LOG_DIR="$installer_base/logs" \
  UNCORDEX_CANONICAL_LOADED=1 UNCORDEX_LAUNCHCTL="$FAKE_LAUNCHCTL" UNCORDEX_LAUNCH_TRACE="$installer_base/launch.trace" "$installer_base/bin/uncordex" uninstall 2>&1)"
uninstall_status=$?
assert_eq "0" "$uninstall_status" "uninstall succeeds"
assert_contains "settings were kept" "$uninstall_output" "uninstall says settings were kept"
if [ ! -e "$installer_base/LaunchAgents/service.plist" ] && [ ! -e "$installer_base/app/watch-power" ] && [ ! -L "$installer_base/bin/uncordex" ]; then pass "uninstall removes the service, files and command"
else fail "uninstall removes the service, files and command"; fi
if [ -r "$installer_base/config/config" ]; then pass "uninstall keeps settings without --purge"
else fail "uninstall keeps settings without --purge"; fi
assert_contains "bootout gui/" "$(/bin/cat "$installer_base/launch.trace")" "uninstall stops the loaded service"

purge_output="$(run_cli success uninstall --purge 2>&1)"
purge_status=$?
assert_eq "0" "$purge_status" "uninstall --purge succeeds"
if [ ! -e "$TEST_ROOT/success/config/config" ]; then pass "uninstall --purge deletes settings"
else fail "uninstall --purge deletes settings"; fi

uninstall_failure_base="$TEST_ROOT/uninstall-failure"
/bin/mkdir -p "$uninstall_failure_base/LaunchAgents"
/usr/bin/printf '%s\n' 'test plist' >"$uninstall_failure_base/LaunchAgents/service.plist"
uninstall_failure_output="$(UNCORDEX_CANONICAL_LOADED=1 UNCORDEX_FAIL_BOOTOUT=1 run_cli uninstall-failure uninstall 2>&1)"
uninstall_failure_status=$?
assert_ne "0" "$uninstall_failure_status" "uninstall reports a failed loaded-service stop"
assert_contains "still running" "$uninstall_failure_output" "failed service stop leaves a clear error"
if [ -e "$uninstall_failure_base/LaunchAgents/service.plist" ]; then pass "failed service stop preserves its LaunchAgent plist"
else fail "failed service stop preserves its LaunchAgent plist"; fi

FAILING_QUERY="$TEST_ROOT/failing-query"
/usr/bin/printf '%s\n' '#!/bin/bash' 'printf "1\\n"' 'exit 2' >"$FAILING_QUERY"
/bin/chmod 755 "$FAILING_QUERY"
query_result="$(UNCORDEX_WATCHER_LIBRARY_ONLY=1 /bin/bash -c '. "$1"; BLUEUTIL="$2"; DEVICE_MAC=AA-BB-CC-DD-EE-FF; speaker_state' _ "$ROOT_DIR/watch-power" "$FAILING_QUERY")"
assert_eq "unknown" "$query_result" "nonzero connection query containing 1 is treated as unknown"

printf '%s tests passed; %s tests failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
