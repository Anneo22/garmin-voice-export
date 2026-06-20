#!/usr/bin/env bash
# install-transcription.sh — opt into transcription. Interactive: pick a backend,
# install it (local backends go in an isolated venv; nothing else is touched), and
# write the config the importer reads. Re-run anytime to change backend/keys.

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$ROOT/.venv"
CONFIG="${GVE_CONFIG:-$HOME/.config/garmin-voice-export/config}"
mkdir -p "$(dirname "$CONFIG")"

echo "Transcription backend:"
echo "  1) Parakeet  — local, offline, free (NVIDIA Parakeet TDT 0.6B v3 via Apple MLX) [recommended]"
echo "  2) Whisper   — local, offline, free (mlx-whisper, more languages)"
echo "  3) OpenAI    — cloud, your API key"
echo "  4) Gemini    — cloud, your API key"
echo "  5) Groq      — cloud, your API key (whisper-large-v3-turbo, fast/cheap)"
echo "  6) Deepgram  — cloud, your API key"
printf "Choice [1]: "; read -r choice; choice="${choice:-1}"

ensure_ffmpeg(){ command -v ffmpeg >/dev/null || { echo "Installing ffmpeg..."; brew install ffmpeg; }; }
ensure_venv(){
  command -v python3 >/dev/null || { echo "python3 required (xcode-select --install or brew install python)"; exit 1; }
  [ -d "$VENV" ] || python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q --upgrade pip >/dev/null 2>&1 || true
}
write_config(){  # backend [keyvar keyval]
  { echo "# garmin-voice-export transcription config (auto-written; chmod 600)"
    echo "GVE_TRANSCRIBE=1"
    echo "GVE_TRANSCRIBE_BACKEND=$1"
    [ -n "${2:-}" ] && echo "$2=$3"
    [ -n "${GVE_OBSIDIAN_VAULT:-}" ] && echo "GVE_OBSIDIAN_VAULT=\"$GVE_OBSIDIAN_VAULT\""
  } > "$CONFIG"
  chmod 600 "$CONFIG"
  echo "Wrote $CONFIG"
}
ask_key(){ local v; printf "Paste your %s API key: " "$1"; read -rs v; echo; echo "$v"; }

case "$choice" in
  1) ensure_ffmpeg; ensure_venv; echo "Installing parakeet-mlx (first transcribe downloads the model ~600MB)..."
     "$VENV/bin/pip" install -q -U parakeet-mlx; write_config parakeet ;;
  2) ensure_ffmpeg; ensure_venv; echo "Installing mlx-whisper..."
     "$VENV/bin/pip" install -q -U mlx-whisper; write_config whisper ;;
  3) k="$(ask_key OpenAI)";   write_config openai   GVE_OPENAI_KEY   "$k" ;;
  4) k="$(ask_key Gemini)";   write_config gemini   GVE_GEMINI_KEY   "$k" ;;
  5) k="$(ask_key Groq)";     write_config groq     GVE_GROQ_KEY     "$k" ;;
  6) k="$(ask_key Deepgram)"; write_config deepgram GVE_DEEPGRAM_KEY "$k" ;;
  *) echo "invalid choice"; exit 1 ;;
esac

printf "Also write each memo into an Obsidian vault? Enter vault path (or leave blank): "
read -r vault
if [ -n "$vault" ]; then printf 'GVE_OBSIDIAN_VAULT="%s"\n' "${vault/#\~/$HOME}" >> "$CONFIG"; fi

echo
echo "Done. Transcription is ON. Test it on an existing memo:"
echo "  GVE_CONFIG='$CONFIG' bin/transcribe-memo.sh '<some>.wav'"
echo "New memos will be transcribed automatically on import."
