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
    if [ "$TEST_CONNECT_COUNT" -ge "$TEST_CONNECT_SUCCEEDS_AT" ]; then
      TEST_CONNECTED=1
      if [ -n "${TEST_SOURCE_AFTER_CONNECT:-}" ]; then TEST_SOURCE="$TEST_SOURCE_AFTER_CONNECT"; fi
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
  /usr/bin/printf '%s\n' '#!/bin/bash' 'exit 0' >"$FAKE_BLUEUTIL"
  # The quoted expressions belong to the generated fake, not this process.
  # shellcheck disable=SC2016
  /usr/bin/printf '%s\n' \
    '#!/bin/bash' \
    'printf "%s\\n" "$*" >> "${UNCORDEX_LAUNCH_TRACE:?}"' \
    'if [ "${1:-}" = print ]; then' \
    '  case "${2:-}" in *com.bolyki.bt-auto-speaker-power) [ "${UNCORDEX_BT_AUTO_LEGACY_SERVICE_PRESENT:-0}" = 1 ] && exit 0 ;; *com.unplugged-speaker.watch-power) [ "${UNCORDEX_UNPLUGGED_LEGACY_SERVICE_PRESENT:-0}" = 1 ] && exit 0 ;; *uk.magrathean.uncordex.watch-power) [ "${UNCORDEX_CANONICAL_LOADED:-0}" = 1 ] && exit 0 ;; esac' \
    '  exit 1' \
    'fi' \
    'if [ "${1:-}" = bootstrap ] && [ "${UNCORDEX_FAIL_BOOTSTRAP_ONCE:-0}" = 1 ] && [ ! -e "${UNCORDEX_LAUNCH_TRACE}.failed-once" ]; then touch "${UNCORDEX_LAUNCH_TRACE}.failed-once"; exit 1; fi' \
    'exit 0' >"$FAKE_LAUNCHCTL"
  /bin/chmod 755 "$FAKE_BLUEUTIL" "$FAKE_LAUNCHCTL"
}

run_installer() {
  install_case="$1"
  shift
  INSTALL_BASE="$TEST_ROOT/$install_case"
  UNCORDEX_THUNDERBOLT_SNAPSHOT="${TEST_THUNDERBOLT_SNAPSHOT:-$FIXTURES/thunderbolt-dock.plist}" \
  UNCORDEX_USB_SNAPSHOT="${TEST_USB_SNAPSHOT:-$FIXTURES/empty.plist}" \
  UNCORDEX_ADAPTER_SNAPSHOT="${TEST_ADAPTER_SNAPSHOT:-$FIXTURES/empty.plist}" \
  UNCORDEX_APP_DIR="$INSTALL_BASE/app" \
  UNCORDEX_CONFIG_DIR="$INSTALL_BASE/config" \
  UNCORDEX_STATE_DIR="$INSTALL_BASE/state" \
  UNCORDEX_PLIST="$INSTALL_BASE/LaunchAgents/service.plist" \
  UNCORDEX_LOG_DIR="$INSTALL_BASE/logs" \
  UNCORDEX_BLUEUTIL="$FAKE_BLUEUTIL" \
  UNCORDEX_LAUNCHCTL="$FAKE_LAUNCHCTL" \
  UNCORDEX_LAUNCH_TRACE="$INSTALL_BASE/launch.trace" \
  "$ROOT_DIR/install.sh" "$@"
}

make_fake_install_tools

gui_missing_plist="$TEST_ROOT/gui-status-missing.plist"
run_installer gui-status-missing --gui-status-plist >"$gui_missing_plist"
assert_eq "missing" "$(/usr/bin/plutil -extract config_state raw -n "$gui_missing_plist")" "GUI status reports missing configuration without creating it"
if [ ! -e "$TEST_ROOT/gui-status-missing" ]; then pass "GUI status is read-only"
else fail "GUI status is read-only"; fi

gui_valid_base="$TEST_ROOT/gui-status-valid"
/bin/mkdir -p "$gui_valid_base/config"
/usr/bin/printf '%s\n' \
  'CONFIG_VERSION=1' \
  'DEVICE_MAC=AA-BB-CC-DD-EE-FF' \
  "BLUEUTIL=$FAKE_BLUEUTIL" \
  'RECONNECT_MODE=source' \
  'SOURCE_KIND=thunderbolt' \
  "SOURCE_KEY=$dock_key" \
  'SOURCE_LABEL=Test\ Dock' >"$gui_valid_base/config/config"
gui_valid_plist="$TEST_ROOT/gui-status-valid.plist"
run_installer gui-status-valid --gui-status-plist >"$gui_valid_plist"
assert_eq "valid" "$(/usr/bin/plutil -extract config_state raw -n "$gui_valid_plist")" "GUI status validates installer-owned configuration"
assert_eq "match" "$(/usr/bin/plutil -extract current_source raw -n "$gui_valid_plist")" "GUI status distinguishes a current source reading"

INSTALL_BASE="$TEST_ROOT/discover"
discover_output="$(run_installer discover --discover 2>&1)"
discover_status=$?
assert_eq "0" "$discover_status" "read-only source discovery succeeds"
assert_contains "Example Vendor Desk Dock" "$discover_output" "discovery displays the usable dock"
if [ ! -e "$TEST_ROOT/discover" ]; then pass "discovery creates no persistent installation files"
else fail "discovery creates no persistent installation files"; fi

TEST_THUNDERBOLT_SNAPSHOT="$FIXTURES/malformed.plist"
export TEST_THUNDERBOLT_SNAPSHOT
discovery_failure_output="$(run_installer discovery-failure --discover 2>&1)"
discovery_failure_status=$?
unset TEST_THUNDERBOLT_SNAPSHOT
assert_ne "0" "$discovery_failure_status" "hardware discovery failure is reported"
assert_contains "Hardware discovery failed" "$discovery_failure_output" "discovery failure is explicit"

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

TEST_USB_SNAPSHOT="$FIXTURES/usb-hub.plist"
export TEST_USB_SNAPSHOT
multiple_output="$(/usr/bin/printf '2\n' | run_installer guided-multiple AA-BB-CC-DD-EE-FF --dry-run 2>&1)"
multiple_status=$?
unset TEST_USB_SNAPSHOT UNCORDEX_FORCE_INTERACTIVE
assert_eq "0" "$multiple_status" "guided setup accepts a choice among multiple sources"
assert_contains "Desk USB-C Hub" "$multiple_output" "guided setup previews the chosen source"

dry_output="$(run_installer dry AA-BB-CC-DD-EE-FF --any-power --dry-run 2>&1)"
dry_status=$?
assert_eq "0" "$dry_status" "explicit any-power dry-run validates"
assert_contains "any external power" "$dry_output" "dry-run previews broad matching clearly"
if [ ! -e "$TEST_ROOT/dry" ]; then pass "dry-run leaves installation paths untouched"
else fail "dry-run leaves installation paths untouched"; fi

no_dependency_install_output="$(run_installer no-dependency-install AA-BB-CC-DD-EE-FF --any-power --no-install-dependencies 2>&1)"
no_dependency_install_status=$?
assert_eq "0" "$no_dependency_install_status" "app-managed setup accepts the no-dependency-install boundary"
assert_contains "Installed uk.magrathean.uncordex.watch-power" "$no_dependency_install_output" "no-dependency-install setup still uses the canonical installer"

conflict_output="$(run_installer conflict AA-BB-CC-DD-EE-FF --any-power --disconnect-only --dry-run 2>&1)"
conflict_status=$?
assert_ne "0" "$conflict_status" "conflicting mode flags fail"
assert_contains "mutually exclusive" "$conflict_output" "mode conflict explains the correction"

missing_output="$(run_installer missing AA-BB-CC-DD-EE-FF --dry-run 2>&1)"
missing_status=$?
assert_ne "0" "$missing_status" "first noninteractive install requires a deliberate mode"
assert_contains "requires --source" "$missing_output" "missing-mode error lists explicit choices"

invalid_output="$(run_installer invalid AA-BB-CC-DD-EE-FF --source deadbeef --dry-run 2>&1)"
invalid_status=$?
assert_ne "0" "$invalid_status" "unknown source keys are rejected"
assert_contains "not a unique usable source" "$invalid_output" "invalid source error fails closed"

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
case "$staging_output" in *"Installed uk.magrathean.uncordex.watch-power"*) fail "staging failure never reports installation success" ;; *) pass "staging failure never reports installation success" ;; esac
if [ ! -e "$TEST_ROOT/staging-failure" ]; then pass "staging failure leaves existing service paths untouched"
else fail "staging failure leaves existing service paths untouched"; fi

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
preserve_output="$(run_installer preserve AA-BB-CC-DD-EE-FF --dry-run 2>&1)"
preserve_status=$?
assert_eq "0" "$preserve_status" "update can preserve an existing exact-source rule"
assert_contains "Saved Dock" "$preserve_output" "preserved rule is shown in the preview"

success_output="$(run_installer success AA-BB-CC-DD-EE-FF --any-power 2>&1)"
success_status=$?
assert_eq "0" "$success_status" "isolated installation activates successfully"
assert_contains "Installed uk.magrathean.uncordex.watch-power" "$success_output" "successful installation reports the canonical service"
if [ -x "$TEST_ROOT/success/app/watch-power" ] && [ -r "$TEST_ROOT/success/app/lib/source.sh" ]; then pass "installation includes watcher and source library"
else fail "installation includes watcher and source library"; fi
assert_contains "RECONNECT_MODE=any_power" "$(/bin/cat "$TEST_ROOT/success/config/config")" "installed configuration records the explicit mode"
if /usr/bin/plutil -lint "$TEST_ROOT/success/LaunchAgents/service.plist" >/dev/null; then pass "installed LaunchAgent is a valid plist"
else fail "installed LaunchAgent is a valid plist"; fi
status_state="$TEST_ROOT/status-only/runtime-state"
status_output="$(UNCORDEX_WATCHER_LIBRARY_ONLY=0 UNCORDEX_CONFIG_FILE="$TEST_ROOT/success/config/config" UNCORDEX_STATE_FILE="$status_state" "$TEST_ROOT/success/app/watch-power" --status 2>&1)"
status_status=$?
assert_eq "0" "$status_status" "installed watcher status is readable"
assert_contains "mode: any_power" "$status_output" "status reports the configured rule"
if [ ! -e "$status_state" ]; then pass "status does not create runtime state"
else fail "status does not create runtime state"; fi
status_plist="$TEST_ROOT/status-only/watcher-status.plist"
/bin/mkdir -p "$TEST_ROOT/status-only"
UNCORDEX_WATCHER_LIBRARY_ONLY=0 UNCORDEX_CONFIG_FILE="$TEST_ROOT/success/config/config" UNCORDEX_STATE_FILE="$status_state" "$TEST_ROOT/success/app/watch-power" --status-plist >"$status_plist"
assert_eq "false" "$(/usr/bin/plutil -extract state_valid raw -n "$status_plist")" "machine watcher status marks missing cache as invalid"

UNCORDEX_UNPLUGGED_LEGACY_SERVICE_PRESENT=1
export UNCORDEX_UNPLUGGED_LEGACY_SERVICE_PRESENT
legacy_unplugged_output="$(run_installer legacy-unplugged AA-BB-CC-DD-EE-FF --any-power 2>&1)"
legacy_unplugged_status=$?
unset UNCORDEX_UNPLUGGED_LEGACY_SERVICE_PRESENT
assert_ne "0" "$legacy_unplugged_status" "prior public watcher blocks a competing installation"
assert_contains "com.unplugged-speaker.watch-power" "$legacy_unplugged_output" "prior public watcher identifies itself"
if [ ! -e "$TEST_ROOT/legacy-unplugged" ]; then pass "prior public watcher check occurs before persistent writes"
else fail "prior public watcher check occurs before persistent writes"; fi

UNCORDEX_BT_AUTO_LEGACY_SERVICE_PRESENT=1
export UNCORDEX_BT_AUTO_LEGACY_SERVICE_PRESENT
legacy_bt_auto_output="$(run_installer legacy-bt-auto AA-BB-CC-DD-EE-FF --any-power 2>&1)"
legacy_bt_auto_status=$?
unset UNCORDEX_BT_AUTO_LEGACY_SERVICE_PRESENT
assert_ne "0" "$legacy_bt_auto_status" "older watcher blocks a competing installation"
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
assert_contains "previous installation was restored" "$rollback_output" "rollback is reported clearly"
assert_eq "old-watcher" "$(/bin/cat "$rollback_base/app/watch-power")" "activation failure restores watcher"
assert_eq "old-library" "$(/bin/cat "$rollback_base/app/lib/source.sh")" "activation failure restores source library"
assert_eq "# old-config" "$(/bin/cat "$rollback_base/config/config")" "activation failure restores configuration"
assert_eq "old-plist" "$(/bin/cat "$rollback_base/LaunchAgents/service.plist")" "activation failure restores LaunchAgent"
assert_eq "2" "$(/usr/bin/grep -c '^bootstrap ' "$rollback_base/launch.trace")" "rollback reactivates a previously loaded service"

FAILING_QUERY="$TEST_ROOT/failing-query"
/usr/bin/printf '%s\n' '#!/bin/bash' 'printf "1\\n"' 'exit 2' >"$FAILING_QUERY"
/bin/chmod 755 "$FAILING_QUERY"
query_result="$(UNCORDEX_WATCHER_LIBRARY_ONLY=1 /bin/bash -c '. "$1"; BLUEUTIL="$2"; DEVICE_MAC=AA-BB-CC-DD-EE-FF; speaker_state' _ "$ROOT_DIR/watch-power" "$FAILING_QUERY")"
assert_eq "unknown" "$query_result" "nonzero connection query containing 1 is treated as unknown"

printf '%s tests passed; %s tests failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
