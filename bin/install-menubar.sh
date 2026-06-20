#!/usr/bin/env bash
# install-menubar.sh — build the menu-bar app and start it at login.
# Optional convenience UI on top of the importer; safe to skip.

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SRC="$ROOT/src/garmin-voice-menubar.swift"
APP="$ROOT/GarminVoiceMemos.app"
BIN="$APP/Contents/MacOS/garmin-voice-menubar"
CTL="$HERE/garmin-voice"
DEST="${GARMIN_VOICE_DEST:-$HOME/Documents/Voice Memos}"
LABEL="com.garminvoice.menubar"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
UID_NUM="$(id -u)"

echo "Building menu-bar app..."
mkdir -p "$APP/Contents/MacOS"
swiftc -O "$SRC" -o "$BIN"
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Garmin Voice Memos</string>
  <key>CFBundleIdentifier</key><string>$LABEL</string>
  <key>CFBundleExecutable</key><string>garmin-voice-menubar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PL

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$BIN</string></array>
  <key>EnvironmentVariables</key><dict>
    <key>GVE_CTL</key><string>$CTL</string>
    <key>GVE_DEST</key><string>$DEST</string>
  </dict>
  <key>RunAtLoad</key><true/>
</dict></plist>
PL

launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST"
echo "Menu-bar app installed and started (look for the ◎ waveform icon in the menu bar)."
echo "  Remove with: launchctl bootout gui/$UID_NUM/$LABEL; rm -rf '$APP' '$PLIST'"
