#!/bin/bash
# Usage: ./install.sh AA-BB-CC-DD-EE-FF
set -euo pipefail

DEVICE_MAC="${1:-}"
if [[ ! "$DEVICE_MAC" =~ ^([[:xdigit:]]{2}[:-]){5}[[:xdigit:]]{2}$ ]]; then
  echo "Usage: $0 AA-BB-CC-DD-EE-FF" >&2
  exit 64
fi

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$HOME/.local/share/unplugged-speaker"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/unplugged-speaker"
PLIST="$HOME/Library/LaunchAgents/com.unplugged-speaker.watch-power.plist"
LABEL="com.unplugged-speaker.watch-power"

command -v brew >/dev/null || { echo "Homebrew is required: https://brew.sh" >&2; exit 1; }
command -v blueutil >/dev/null || brew install blueutil
BLUEUTIL_PATH="$(command -v blueutil)"
[ -x "$BLUEUTIL_PATH" ] || { echo "blueutil was installed but is not executable" >&2; exit 1; }

mkdir -p "$APP_DIR" "$CONFIG_DIR" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
install -m 755 "$REPO_DIR/watch-power" "$APP_DIR/watch-power"
printf 'DEVICE_MAC=%q\nBLUEUTIL=%q\n' "$DEVICE_MAC" "$BLUEUTIL_PATH" > "$CONFIG_DIR/config"

/bin/launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$APP_DIR/watch-power</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/unplugged-speaker.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/unplugged-speaker-error.log</string>
</dict></plist>
EOF
/usr/bin/plutil -lint "$PLIST"
/bin/launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed. Speaker disconnects on battery and reconnects on AC."
