#!/bin/bash
# Hardware-source discovery for Uncordex.
# This file is a library: sourcing it performs no reads and changes no state.

SOURCE_KEYS=()
SOURCE_KINDS=()
SOURCE_LABELS=()

_source_plutil="${UNCORDEX_PLUTIL:-/usr/bin/plutil}"
_source_ioreg="${UNCORDEX_IOREG:-/usr/sbin/ioreg}"
_source_shasum="${UNCORDEX_SHASUM:-/usr/bin/shasum}"

_source_clean_text() {
  local text
  text="$1"
  # Device labels are display-only. Keep them to one printable line.
  /usr/bin/printf '%s' "$text" | /usr/bin/tr '\r\n\t' '   ' | /usr/bin/sed 's/[[:cntrl:]]//g; s/  */ /g; s/^ //; s/ $//'
}

_source_valid_identity() {
  local compact
  case "$1" in
    ""|0|00|000|0000|unknown|UNKNOWN|Unknown|none|NONE|None|n/a|N/A|NULL|null)
      return 1
      ;;
  esac
  compact="$(/usr/bin/printf '%s' "$1" | /usr/bin/tr -d '0xX:_ -')"
  [ -n "$compact" ] || return 1
  return 0
}

source_key() {
  local kind field
  [ "$#" -ge 2 ] || return 64
  kind="$1"
  shift
  case "$kind" in
    thunderbolt|usb|adapter) ;;
    *) return 64 ;;
  esac

  {
    /usr/bin/printf '%s\0' "$kind"
    for field in "$@"; do
      /usr/bin/printf '%s\0' "$field"
    done
  } | "$_source_shasum" -a 256 | /usr/bin/awk '{print $1}'
}

_source_value() {
  local path file
  path="$1"
  file="$2"
  "$_source_plutil" -extract "$path" raw -n "$file" 2>/dev/null
}

_source_snapshot() {
  local kind destination override
  kind="$1"
  destination="$2"
  override=""

  case "$kind" in
    thunderbolt) override="${UNCORDEX_THUNDERBOLT_SNAPSHOT:-}" ;;
    usb) override="${UNCORDEX_USB_SNAPSHOT:-}" ;;
    adapter) override="${UNCORDEX_ADAPTER_SNAPSHOT:-}" ;;
    *) return 64 ;;
  esac

  if [ -n "$override" ]; then
    [ -r "$override" ] || return 1
    /bin/cp "$override" "$destination" || return 1
  else
    case "$kind" in
      thunderbolt)
        _source_run_bounded "$destination" "$_source_ioreg" -r -c IOThunderboltSwitch -d 1 -l -w 0 -a || return 1
        ;;
      usb)
        _source_run_bounded "$destination" "$_source_ioreg" -r -c IOUSBHostDevice -l -w 0 -a || return 1
        ;;
      adapter)
        _source_run_bounded "$destination" "$_source_ioreg" -r -c AppleSmartBattery -d 1 -a || return 1
        ;;
    esac
  fi

  "$_source_plutil" -lint "$destination" >/dev/null 2>&1
}

_source_run_bounded() {
  local destination command_pid ticks
  destination="$1"
  shift

  "$@" >"$destination" 2>/dev/null &
  command_pid=$!
  ticks=0
  while /bin/kill -0 "$command_pid" 2>/dev/null; do
    if [ "$ticks" -ge 100 ]; then
      /bin/kill -TERM "$command_pid" 2>/dev/null || true
      /bin/sleep 1
      /bin/kill -KILL "$command_pid" 2>/dev/null || true
      wait "$command_pid" 2>/dev/null || true
      return 124
    fi
    /bin/sleep 0.1
    ticks=$((ticks + 1))
  done
  wait "$command_pid"
}

_source_add_candidate() {
  local kind key label index last_index move_index next_index
  kind="$1"
  key="$2"
  label="$3"

  index=0
  while [ "$index" -lt "${#SOURCE_KEYS[@]}" ]; do
    if [ "${SOURCE_KINDS[$index]}" = "$kind" ] && [ "${SOURCE_KEYS[$index]}" = "$key" ]; then
      # Duplicate hardware identities are not exact identities. Remove the
      # earlier candidate and remember the key so later duplicates stay out.
      last_index=$((${#SOURCE_KEYS[@]} - 1))
      move_index="$index"
      while [ "$move_index" -lt "$last_index" ]; do
        next_index=$((move_index + 1))
        SOURCE_KEYS[move_index]="${SOURCE_KEYS[next_index]}"
        SOURCE_KINDS[move_index]="${SOURCE_KINDS[next_index]}"
        SOURCE_LABELS[move_index]="${SOURCE_LABELS[next_index]}"
        move_index="$next_index"
      done
      unset 'SOURCE_KEYS[$last_index]'
      unset 'SOURCE_KINDS[$last_index]'
      unset 'SOURCE_LABELS[$last_index]'
      _SOURCE_DUPLICATE_KEYS="${_SOURCE_DUPLICATE_KEYS}${kind}:${key}\n"
      return 0
    fi
    index=$((index + 1))
  done

  if /usr/bin/printf '%b' "$_SOURCE_DUPLICATE_KEYS" | /usr/bin/grep -Fqx "${kind}:${key}"; then
    return 0
  fi

  SOURCE_KEYS[${#SOURCE_KEYS[@]}]="$key"
  SOURCE_KINDS[${#SOURCE_KINDS[@]}]="$kind"
  SOURCE_LABELS[${#SOURCE_LABELS[@]}]="$label"
}

_source_scan_thunderbolt() {
  local file index route uid uid_digits vendor model label key
  file="$1"
  index=0
  while "$_source_plutil" -type "$index" "$file" >/dev/null 2>&1; do
    route="$(_source_value "$index.Route String" "$file")" || route=""
    uid="$(_source_value "$index.UID" "$file")" || uid=""
    case "$route" in
      ''|*[!0-9]*) _SOURCE_SCAN_UNCERTAIN=1; index=$((index + 1)); continue ;;
    esac
    if [ "$route" -gt 0 ]; then
      uid_digits="$uid"
      case "$uid_digits" in -*) uid_digits="${uid_digits#-}" ;; esac
      case "$uid_digits" in ''|*[!0-9]*) _SOURCE_SCAN_UNCERTAIN=1; index=$((index + 1)); continue ;; esac
      if ! _source_valid_identity "$uid"; then
        _SOURCE_SCAN_UNCERTAIN=1
      else
        vendor="$(_source_value "$index.Device Vendor Name" "$file")" || vendor=""
        model="$(_source_value "$index.Device Model Name" "$file")" || model=""
        label="$(_source_clean_text "$vendor $model")"
        [ -n "$label" ] || label="Thunderbolt / USB4 device"
        key="$(source_key thunderbolt "$uid")" || return 1
        _source_add_candidate thunderbolt "$key" "$label"
      fi
    fi
    index=$((index + 1))
  done
}

_source_scan_usb() {
  local file index device_class vendor product serial label key
  file="$1"
  index=0
  while "$_source_plutil" -type "$index" "$file" >/dev/null 2>&1; do
    device_class="$(_source_value "$index.bDeviceClass" "$file")" || device_class=""
    if [ "$device_class" = "9" ]; then
      vendor="$(_source_value "$index.idVendor" "$file")" || vendor=""
      product="$(_source_value "$index.idProduct" "$file")" || product=""
      serial="$(_source_value "$index.USB Serial Number" "$file")" || serial=""
      if ! _source_valid_identity "$vendor" || ! _source_valid_identity "$product" || ! _source_valid_identity "$serial"; then
        _SOURCE_SCAN_UNCERTAIN=1
      else
        label="$(_source_value "$index.USB Product Name" "$file")" || label=""
        label="$(_source_clean_text "$label")"
        [ -n "$label" ] || label="Serialized USB hub"
        key="$(source_key usb "$vendor" "$product" "$serial")" || return 1
        _source_add_candidate usb "$key" "$label"
      fi
    fi
    index=$((index + 1))
  done
}

_source_scan_adapter() {
  local file index serial family label key
  file="$1"
  index=0
  while "$_source_plutil" -type "$index" "$file" >/dev/null 2>&1; do
    if "$_source_plutil" -type "$index.AdapterDetails" "$file" >/dev/null 2>&1; then
      serial="$(_source_value "$index.AdapterDetails.SerialNumber" "$file")" || serial=""
      family="$(_source_value "$index.AdapterDetails.FamilyCode" "$file")" || family=""
      if ! _source_valid_identity "$serial" || ! _source_valid_identity "$family"; then
        _SOURCE_SCAN_UNCERTAIN=1
      else
        label="$(_source_value "$index.AdapterDetails.Description" "$file")" || label=""
        label="$(_source_clean_text "$label")"
        [ -n "$label" ] || label="Serialized power adapter"
        key="$(source_key adapter "$serial" "$family")" || return 1
        _source_add_candidate adapter "$key" "$label"
      fi
    fi
    index=$((index + 1))
  done
}

_source_enumerate_kind() {
  local kind temp_dir snapshot result
  kind="$1"
  temp_dir="${UNCORDEX_SOURCE_TEMP_DIR:-${TMPDIR:-/tmp}}"
  snapshot="$(/usr/bin/mktemp "$temp_dir/uncordex-source.XXXXXX")" || return 1
  if ! _source_snapshot "$kind" "$snapshot"; then
    /bin/rm -f "$snapshot"
    return 1
  fi

  case "$kind" in
    thunderbolt) _source_scan_thunderbolt "$snapshot" ;;
    usb) _source_scan_usb "$snapshot" ;;
    adapter) _source_scan_adapter "$snapshot" ;;
  esac
  result=$?
  /bin/rm -f "$snapshot"
  return "$result"
}

discover_sources() {
  SOURCE_KEYS=()
  SOURCE_KINDS=()
  SOURCE_LABELS=()
  _SOURCE_DUPLICATE_KEYS=""
  _SOURCE_SCAN_UNCERTAIN=0

  _source_enumerate_kind thunderbolt || return 1
  _source_enumerate_kind usb || return 1
  _source_enumerate_kind adapter || return 1
  return 0
}

source_presence() {
  local kind wanted_key index
  kind="$1"
  wanted_key="$2"
  case "$kind" in
    thunderbolt|usb|adapter) ;;
    *) /usr/bin/printf '%s\n' unknown; return 0 ;;
  esac

  SOURCE_KEYS=()
  SOURCE_KINDS=()
  SOURCE_LABELS=()
  _SOURCE_DUPLICATE_KEYS=""
  _SOURCE_SCAN_UNCERTAIN=0
  if ! _source_enumerate_kind "$kind"; then
    /usr/bin/printf '%s\n' unknown
    return 0
  fi
  if /usr/bin/printf '%b' "$_SOURCE_DUPLICATE_KEYS" | /usr/bin/grep -Fqx "${kind}:${wanted_key}"; then
    /usr/bin/printf '%s\n' unknown
    return 0
  fi

  index=0
  while [ "$index" -lt "${#SOURCE_KEYS[@]}" ]; do
    if [ "${SOURCE_KEYS[$index]}" = "$wanted_key" ]; then
      /usr/bin/printf '%s\n' match
      return 0
    fi
    index=$((index + 1))
  done

  if [ "$_SOURCE_SCAN_UNCERTAIN" -ne 0 ]; then
    /usr/bin/printf '%s\n' unknown
  else
    /usr/bin/printf '%s\n' absent
  fi
}
