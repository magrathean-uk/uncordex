#!/bin/bash
# Install or update Uncordex for the logged-in macOS user.
set -euo pipefail

usage() {
  /usr/bin/printf '%s\n' \
    "Usage:" \
    "  $0 [SPEAKER_ADDRESS]" \
    "  $0 SPEAKER_ADDRESS --source KEY" \
    "  $0 SPEAKER_ADDRESS --any-power" \
    "  $0 SPEAKER_ADDRESS --disconnect-only" \
    "  $0 [SPEAKER_ADDRESS] --relearn" \
    "  $0 --discover" \
    "  Add --dry-run to validate and preview without installing."
}

fail() { /usr/bin/printf 'Error: %s\n' "$*" >&2; exit 64; }

is_interactive() { [ "${UNCORDEX_FORCE_INTERACTIVE:-0}" = 1 ] || [ -t 0 ]; }

REPO_DIR="$(cd "$(/usr/bin/dirname "$0")" && pwd)"
APP_DIR="${UNCORDEX_APP_DIR:-$HOME/.local/share/uncordex}"
CONFIG_DIR="${UNCORDEX_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/uncordex}"
STATE_DIR="${UNCORDEX_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/uncordex}"
PLIST="${UNCORDEX_PLIST:-$HOME/Library/LaunchAgents/uk.magrathean.uncordex.watch-power.plist}"
LOG_DIR="${UNCORDEX_LOG_DIR:-$HOME/Library/Logs}"
CONFIG_FILE="$CONFIG_DIR/config"
LABEL="uk.magrathean.uncordex.watch-power"
LAUNCHCTL="${UNCORDEX_LAUNCHCTL:-/bin/launchctl}"
PLUTIL="${UNCORDEX_PLUTIL:-/usr/bin/plutil}"

REQUESTED_MAC=""
REQUESTED_SOURCE=""
REQUEST_ANY=0
REQUEST_DISCONNECT=0
RELEARN=0
DISCOVER_ONLY=0
DRY_RUN=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source)
      [ "$#" -ge 2 ] || fail "--source requires a key"
      REQUESTED_SOURCE="$2"
      shift 2
      ;;
    --any-power) REQUEST_ANY=1; shift ;;
    --disconnect-only) REQUEST_DISCONNECT=1; shift ;;
    --relearn) RELEARN=1; shift ;;
    --discover) DISCOVER_ONLY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --*) fail "unknown option: $1" ;;
    *)
      [ -z "$REQUESTED_MAC" ] || fail "only one speaker address may be supplied"
      REQUESTED_MAC="$1"
      shift
      ;;
  esac
done

mode_count=0
[ -n "$REQUESTED_SOURCE" ] && mode_count=$((mode_count + 1))
[ "$REQUEST_ANY" -eq 1 ] && mode_count=$((mode_count + 1))
[ "$REQUEST_DISCONNECT" -eq 1 ] && mode_count=$((mode_count + 1))
[ "$mode_count" -le 1 ] || fail "--source, --any-power, and --disconnect-only are mutually exclusive"
[ "$RELEARN" -eq 0 ] || [ "$mode_count" -eq 0 ] || fail "--relearn cannot be combined with a mode flag"

for required in "$PLUTIL" /usr/sbin/ioreg /usr/bin/shasum /usr/bin/mktemp; do
  [ -x "$required" ] || fail "required macOS tool is unavailable: $required"
done
"$PLUTIL" -help 2>&1 | /usr/bin/grep -q -- '-extract' || fail "plutil does not support structured extraction on this macOS version"

# shellcheck source=lib/source.sh
. "$REPO_DIR/lib/source.sh"

mask_key() {
  local key
  key="$1"
  /usr/bin/printf '%s...%s' "${key:0:4}" "${key: -4}"
}

print_sources() {
  local index
  if ! discover_sources; then
    /usr/bin/printf '%s\n' "Hardware discovery failed; no source rule can be learned." >&2
    return 1
  fi
  if [ "${#SOURCE_KEYS[@]}" -eq 0 ]; then
    /usr/bin/printf '%s\n' "No exact source identity is available."
    return 0
  fi
  index=0
  while [ "$index" -lt "${#SOURCE_KEYS[@]}" ]; do
    /usr/bin/printf '%s\t%s\t%s\t%s\n' \
      "$((index + 1))" "${SOURCE_KINDS[$index]}" "${SOURCE_LABELS[$index]}" "${SOURCE_KEYS[$index]}"
    index=$((index + 1))
  done
}

if [ "$DISCOVER_ONLY" -eq 1 ]; then
  [ -z "$REQUESTED_MAC" ] && [ "$mode_count" -eq 0 ] && [ "$RELEARN" -eq 0 ] || fail "--discover cannot be combined with setup options"
  print_sources
  exit $?
fi

SAVED_MAC=""
SAVED_BLUEUTIL=""
SAVED_MODE=""
SAVED_KIND=""
SAVED_KEY=""
SAVED_LABEL=""
if [ -r "$CONFIG_FILE" ]; then
  unset CONFIG_VERSION DEVICE_MAC BLUEUTIL RECONNECT_MODE SOURCE_KIND SOURCE_KEY SOURCE_LABEL 2>/dev/null || true
  # This file is owned by the current user and written with Bash-safe quoting.
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
  SAVED_MAC="${DEVICE_MAC:-}"
  SAVED_BLUEUTIL="${BLUEUTIL:-}"
  SAVED_MODE="${RECONNECT_MODE:-}"
  SAVED_KIND="${SOURCE_KIND:-}"
  SAVED_KEY="${SOURCE_KEY:-}"
  SAVED_LABEL="${SOURCE_LABEL:-}"
fi

find_blueutil() {
  local candidate found
  if [ -n "${UNCORDEX_BLUEUTIL:-}" ] && [ -x "$UNCORDEX_BLUEUTIL" ]; then
    /usr/bin/printf '%s\n' "$UNCORDEX_BLUEUTIL"
    return 0
  fi
  if [ -n "$SAVED_BLUEUTIL" ] && [ -x "$SAVED_BLUEUTIL" ]; then
    /usr/bin/printf '%s\n' "$SAVED_BLUEUTIL"
    return 0
  fi
  for candidate in /opt/homebrew/bin/blueutil /usr/local/bin/blueutil; do
    if [ -x "$candidate" ]; then /usr/bin/printf '%s\n' "$candidate"; return 0; fi
  done
  found="$(command -v blueutil 2>/dev/null || true)"
  [ -n "$found" ] && [ -x "$found" ] || return 1
  /usr/bin/printf '%s\n' "$found"
}

BLUEUTIL_PATH="$(find_blueutil || true)"

if [ -z "$REQUESTED_MAC" ]; then
  if [ -n "$SAVED_MAC" ] && [ "$RELEARN" -eq 0 ]; then
    REQUESTED_MAC="$SAVED_MAC"
  elif is_interactive; then
    [ -n "$BLUEUTIL_PATH" ] || fail "install blueutil before guided speaker selection"
    /usr/bin/printf '%s\n' "Paired Bluetooth devices:"
    "$BLUEUTIL_PATH" --paired || true
    /usr/bin/printf '%s' "Speaker address: "
    IFS= read -r REQUESTED_MAC
  else
    fail "a speaker address is required for noninteractive setup"
  fi
fi

case "$REQUESTED_MAC" in
  [[:xdigit:]][[:xdigit:]][:-][[:xdigit:]][[:xdigit:]][:-][[:xdigit:]][[:xdigit:]][:-][[:xdigit:]][[:xdigit:]][:-][[:xdigit:]][[:xdigit:]][:-][[:xdigit:]][[:xdigit:]]) ;;
  *) fail "speaker address must look like AA-BB-CC-DD-EE-FF" ;;
esac

SELECTED_MODE=""
SELECTED_KIND=""
SELECTED_KEY=""
SELECTED_LABEL=""

resolve_source_key() {
  local wanted index
  wanted="$1"
  discover_sources || fail "hardware discovery failed; the source key was not accepted"
  index=0
  while [ "$index" -lt "${#SOURCE_KEYS[@]}" ]; do
    if [ "${SOURCE_KEYS[$index]}" = "$wanted" ]; then
      SELECTED_MODE=source
      SELECTED_KIND="${SOURCE_KINDS[$index]}"
      SELECTED_KEY="${SOURCE_KEYS[$index]}"
      SELECTED_LABEL="${SOURCE_LABELS[$index]}"
      return 0
    fi
    index=$((index + 1))
  done
  fail "the supplied source key is not a unique usable source currently attached"
}

guided_rule() {
  local answer choice index
  discover_sources || fail "hardware discovery failed; setup was left unchanged"
  if [ "${#SOURCE_KEYS[@]}" -gt 0 ]; then
    /usr/bin/printf '%s\n' "Usable reconnection sources:"
    index=0
    while [ "$index" -lt "${#SOURCE_KEYS[@]}" ]; do
      /usr/bin/printf '  %s) %s (%s)\n' "$((index + 1))" "${SOURCE_LABELS[$index]}" "$(mask_key "${SOURCE_KEYS[$index]}")"
      index=$((index + 1))
    done
    /usr/bin/printf '%s\n' "  a) Any external power" "  d) Disconnect only" "  q) Cancel"
    if [ "${#SOURCE_KEYS[@]}" -eq 1 ]; then /usr/bin/printf '%s' "Choose [1]: "; else /usr/bin/printf '%s' "Choose: "; fi
    IFS= read -r answer
    [ -n "$answer" ] || { [ "${#SOURCE_KEYS[@]}" -eq 1 ] && answer=1; }
  else
    /usr/bin/printf '%s\n' "This Mac does not report a unique dock or charger identity." "  a) Any external power" "  d) Disconnect only" "  q) Cancel"
    /usr/bin/printf '%s' "Choose: "
    IFS= read -r answer
  fi
  case "$answer" in
    a|A) SELECTED_MODE=any_power; SELECTED_LABEL="Any external power" ;;
    d|D) SELECTED_MODE=disconnect_only; SELECTED_LABEL="Disconnect only" ;;
    q|Q|"") fail "setup cancelled; existing installation was not changed" ;;
    *[!0-9]*) fail "invalid selection; existing installation was not changed" ;;
    *)
      choice=$((answer - 1))
      [ "$choice" -ge 0 ] && [ "$choice" -lt "${#SOURCE_KEYS[@]}" ] || fail "invalid selection; existing installation was not changed"
      SELECTED_MODE=source
      SELECTED_KIND="${SOURCE_KINDS[$choice]}"
      SELECTED_KEY="${SOURCE_KEYS[$choice]}"
      SELECTED_LABEL="${SOURCE_LABELS[$choice]}"
      ;;
  esac
}

if [ -n "$REQUESTED_SOURCE" ]; then
  resolve_source_key "$REQUESTED_SOURCE"
elif [ "$REQUEST_ANY" -eq 1 ]; then
  SELECTED_MODE=any_power; SELECTED_LABEL="Any external power"
elif [ "$REQUEST_DISCONNECT" -eq 1 ]; then
  SELECTED_MODE=disconnect_only; SELECTED_LABEL="Disconnect only"
elif [ "$RELEARN" -eq 0 ] && [ -n "$SAVED_MODE" ]; then
  case "$SAVED_MODE" in
    source)
      case "$SAVED_KIND" in thunderbolt|usb|adapter) ;; *) fail "the saved source rule is invalid; use --relearn" ;; esac
      [ "${#SAVED_KEY}" -eq 64 ] || fail "the saved source rule is invalid; use --relearn"
      case "$SAVED_KEY" in *[!0-9a-f]*) fail "the saved source rule is invalid; use --relearn" ;; esac
      SELECTED_MODE=source; SELECTED_KIND="$SAVED_KIND"; SELECTED_KEY="$SAVED_KEY"; SELECTED_LABEL="$SAVED_LABEL"
      ;;
    any_power|disconnect_only)
      SELECTED_MODE="$SAVED_MODE"; SELECTED_LABEL="$SAVED_LABEL"
      ;;
    *) fail "the saved rule is invalid; choose a new mode explicitly" ;;
  esac
elif is_interactive; then
  guided_rule
else
  fail "noninteractive setup requires --source KEY, --any-power, or --disconnect-only"
fi

case "$SELECTED_MODE" in
  source) /usr/bin/printf 'Preview: Reconnect this speaker when %s is attached and the Mac has external power.\n' "$SELECTED_LABEL" ;;
  any_power) /usr/bin/printf '%s\n' "Preview: Reconnect this speaker when any external power is present." ;;
  disconnect_only) /usr/bin/printf '%s\n' "Preview: Disconnect on departure, but never reconnect automatically." ;;
esac

if [ -z "$BLUEUTIL_PATH" ] && [ "$DRY_RUN" -eq 0 ]; then
  BREW="${UNCORDEX_BREW:-$(command -v brew 2>/dev/null || true)}"
  [ -n "$BREW" ] && [ -x "$BREW" ] || fail "Homebrew is required to install blueutil: https://brew.sh"
  "$BREW" install blueutil
  BLUEUTIL_PATH="$(find_blueutil || true)"
fi
[ -n "$BLUEUTIL_PATH" ] || fail "blueutil is required; install it before using --dry-run"

STAGE="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/uncordex-install.XXXXXX")" || exit 1
trap '/bin/rm -rf "$STAGE"' EXIT HUP INT TERM
/bin/mkdir -p "$STAGE/lib"
/usr/bin/install -m 755 "$REPO_DIR/watch-power" "$STAGE/watch-power"
/usr/bin/install -m 644 "$REPO_DIR/lib/source.sh" "$STAGE/lib/source.sh"
printf 'CONFIG_VERSION=1\nDEVICE_MAC=%q\nBLUEUTIL=%q\nRECONNECT_MODE=%q\nSOURCE_KIND=%q\nSOURCE_KEY=%q\nSOURCE_LABEL=%q\n' \
  "$REQUESTED_MAC" "$BLUEUTIL_PATH" "$SELECTED_MODE" "$SELECTED_KIND" "$SELECTED_KEY" "$SELECTED_LABEL" >"$STAGE/config"
/bin/chmod 600 "$STAGE/config"

STAGE_PLIST="$STAGE/service.plist"
"$PLUTIL" -create xml1 "$STAGE_PLIST"
"$PLUTIL" -insert Label -string "$LABEL" "$STAGE_PLIST"
"$PLUTIL" -insert ProgramArguments -array "$STAGE_PLIST"
"$PLUTIL" -insert ProgramArguments.0 -string "$APP_DIR/watch-power" "$STAGE_PLIST"
"$PLUTIL" -insert RunAtLoad -bool true "$STAGE_PLIST"
"$PLUTIL" -insert KeepAlive -bool true "$STAGE_PLIST"
"$PLUTIL" -insert StandardOutPath -string "$LOG_DIR/uncordex.log" "$STAGE_PLIST"
"$PLUTIL" -insert StandardErrorPath -string "$LOG_DIR/uncordex-error.log" "$STAGE_PLIST"
if [ -n "${XDG_CONFIG_HOME:-}${XDG_STATE_HOME:-}" ]; then
  "$PLUTIL" -insert EnvironmentVariables -dictionary "$STAGE_PLIST"
  [ -z "${XDG_CONFIG_HOME:-}" ] || "$PLUTIL" -insert EnvironmentVariables.XDG_CONFIG_HOME -string "$XDG_CONFIG_HOME" "$STAGE_PLIST"
  [ -z "${XDG_STATE_HOME:-}" ] || "$PLUTIL" -insert EnvironmentVariables.XDG_STATE_HOME -string "$XDG_STATE_HOME" "$STAGE_PLIST"
fi

/bin/bash -n "$STAGE/watch-power" "$STAGE/lib/source.sh" || exit 1
"$PLUTIL" -lint "$STAGE_PLIST" >/dev/null || exit 1

if [ "$DRY_RUN" -eq 1 ]; then
  /usr/bin/printf '%s\n' "Dry run complete. No files, packages, or services were changed."
  exit 0
fi

USER_ID="$(/usr/bin/id -u)"
for legacy_label in com.unplugged-speaker.watch-power com.bolyki.bt-auto-speaker-power; do
  if "$LAUNCHCTL" print "gui/$USER_ID/$legacy_label" >/dev/null 2>&1; then
    /usr/bin/printf '%s\n' \
      "A legacy speaker watcher ($legacy_label) is running." \
      "Installation stopped to prevent two services controlling the speaker." \
      "Review and stop that exact service before performing a controlled migration." >&2
    exit 1
  fi
done
SERVICE_WAS_LOADED=0
if "$LAUNCHCTL" print "gui/$USER_ID/$LABEL" >/dev/null 2>&1; then SERVICE_WAS_LOADED=1; fi

BACKUP_DIR="$STATE_DIR/install-backups/$(/bin/date '+%Y%m%d-%H%M%S')-$$"
/bin/mkdir -p "$BACKUP_DIR"
had_watcher=0; had_library=0; had_config=0; had_plist=0
if [ -e "$APP_DIR/watch-power" ]; then /bin/cp -p "$APP_DIR/watch-power" "$BACKUP_DIR/watch-power"; had_watcher=1; fi
if [ -e "$APP_DIR/lib/source.sh" ]; then /bin/cp -p "$APP_DIR/lib/source.sh" "$BACKUP_DIR/source.sh"; had_library=1; fi
if [ -e "$CONFIG_FILE" ]; then /bin/cp -p "$CONFIG_FILE" "$BACKUP_DIR/config"; had_config=1; fi
if [ -e "$PLIST" ]; then /bin/cp -p "$PLIST" "$BACKUP_DIR/service.plist"; had_plist=1; fi

restore_previous() {
  "$LAUNCHCTL" bootout "gui/$USER_ID" "$PLIST" >/dev/null 2>&1 || true
  if [ "$had_watcher" -eq 1 ]; then /bin/cp -p "$BACKUP_DIR/watch-power" "$APP_DIR/watch-power"; else /bin/rm -f "$APP_DIR/watch-power"; fi
  if [ "$had_library" -eq 1 ]; then /bin/cp -p "$BACKUP_DIR/source.sh" "$APP_DIR/lib/source.sh"; else /bin/rm -f "$APP_DIR/lib/source.sh"; fi
  if [ "$had_config" -eq 1 ]; then /bin/cp -p "$BACKUP_DIR/config" "$CONFIG_FILE"; else /bin/rm -f "$CONFIG_FILE"; fi
  if [ "$had_plist" -eq 1 ]; then
    /bin/cp -p "$BACKUP_DIR/service.plist" "$PLIST"
    if [ "$SERVICE_WAS_LOADED" -eq 1 ]; then "$LAUNCHCTL" bootstrap "gui/$USER_ID" "$PLIST" >/dev/null 2>&1 || true; fi
  else
    /bin/rm -f "$PLIST"
  fi
}

/bin/mkdir -p "$APP_DIR/lib" "$CONFIG_DIR" "$(/usr/bin/dirname "$PLIST")" "$LOG_DIR"
"$LAUNCHCTL" bootout "gui/$USER_ID" "$PLIST" >/dev/null 2>&1 || true
if ! /usr/bin/install -m 755 "$STAGE/watch-power" "$APP_DIR/watch-power" ||
   ! /usr/bin/install -m 644 "$STAGE/lib/source.sh" "$APP_DIR/lib/source.sh" ||
   ! /usr/bin/install -m 600 "$STAGE/config" "$CONFIG_FILE" ||
   ! /usr/bin/install -m 644 "$STAGE_PLIST" "$PLIST"; then
  restore_previous
  /usr/bin/printf '%s\n' "Installation failed; previous files were restored from $BACKUP_DIR" >&2
  exit 1
fi

if ! "$LAUNCHCTL" bootstrap "gui/$USER_ID" "$PLIST"; then
  restore_previous
  /usr/bin/printf '%s\n' "LaunchAgent activation failed; previous installation was restored from $BACKUP_DIR" >&2
  exit 1
fi

/usr/bin/printf '%s\n' "Installed $LABEL." "Previous files, if any, are backed up at $BACKUP_DIR"
