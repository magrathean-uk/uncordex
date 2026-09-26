#!/bin/bash
set -euo pipefail

PLIST="${UNCORDEX_PLIST:-$HOME/Library/LaunchAgents/uk.magrathean.uncordex.watch-power.plist}"
LAUNCHCTL="${UNCORDEX_LAUNCHCTL:-/bin/launchctl}"
LABEL="uk.magrathean.uncordex.watch-power"
USER_ID="$(/usr/bin/id -u)"

if "$LAUNCHCTL" print "gui/$USER_ID/$LABEL" >/dev/null 2>&1; then
  if ! "$LAUNCHCTL" bootout "gui/$USER_ID" "$PLIST"; then
    /usr/bin/printf '%s\n' "Uncordex is still running; its LaunchAgent was left in place." >&2
    exit 1
  fi
fi
/bin/rm -f "$PLIST"
echo "Stopped Uncordex. App files and config left in place."
