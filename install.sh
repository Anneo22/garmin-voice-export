#!/usr/bin/env bash
# install.sh — one-command setup for Garmin Voice Memos.
# Installs dependencies, asks a few questions, and sets up the on-connect importer.
# Re-run anytime to change options. Everything it does is reversible.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$HERE/bin"

echo "Garmin Voice Memos — setup"
echo "=========================="

# --- dependencies ---
if ! command -v brew >/dev/null; then
  echo "Homebrew is required: https://brew.sh"; exit 1
fi
for f in gphoto2 terminal-notifier; do
  command -v "$f" >/dev/null || { echo "Installing $f..."; brew install "$f"; }
done
xcrun -f swiftc >/dev/null 2>&1 || echo "NOTE: the instant-on-connect watcher needs Xcode CLT — run: xcode-select --install"

ask(){ local q="$1" def="$2" a; printf "%s [%s]: " "$q" "$def"; read -r a; echo "${a:-$def}"; }
# yesno <question> <default Y|N> — default applies on empty input
yesno(){ local q="$1" def="$2" a hint; [ "$def" = Y ] && hint="Y/n" || hint="y/N"
  printf "%s (%s): " "$q" "$hint"; read -r a; a="${a:-$def}"; [[ "$a" =~ ^[Yy] ]]; }

echo
DEST="$(ask "Where should voice memos be saved?" "$HOME/Documents/Voice Memos")"
DEL=""
if yesno "Delete each memo from the watch after a verified copy?" N; then DEL="--delete"; fi
echo

# --- core agent ---
GARMIN_VOICE_DEST="$DEST" GARMIN_VOICE_DELETE="$DEL" bash "$BIN/install-autorun.sh"

# --- optional: transcription ---
echo
if yesno "Set up transcription now (local model or cloud key)?" N; then
  bash "$BIN/install-transcription.sh"
fi

# --- optional: menu-bar app ---
echo
if yesno "Install the menu-bar app?" Y; then
  GARMIN_VOICE_DEST="$DEST" bash "$BIN/install-menubar.sh"
fi

echo
echo "All set. Plug in your Garmin watch — new memos will import automatically to:"
echo "  $DEST"
echo "Controls: $BIN/garmin-voice {status|pause|resume|free|sync}"
