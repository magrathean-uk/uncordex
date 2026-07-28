#!/bin/bash
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/com.unplugged-speaker.watch-power.plist"
/bin/launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
/bin/rm -f "$PLIST"
echo "Stopped. App files and config left in place."
