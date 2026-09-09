#!/bin/bash
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/uk.magrathean.uncordex.watch-power.plist"
/bin/launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
/bin/rm -f "$PLIST"
echo "Stopped Uncordex. App files and config left in place."
