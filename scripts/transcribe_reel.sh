#!/usr/bin/env bash
set -euo pipefail

# Usage: ./transcribe_reel.sh <instagram_reel_url> [cookies_file]
# Downloads an Instagram reel, extracts audio, and transcribes to text.
# Optional second arg: path to cookies.txt (Netscape) for authenticated download.

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <instagram_reel_url> [cookies_file]"
  exit 1
fi

URL="$1"
COOKIES_FILE="${2:-}"
WORKDIR="$(pwd)/output_$(date +%s)"
mkdir -p "$WORKDIR"

command -v yt-dlp >/dev/null 2>&1 || { echo "yt-dlp is required. Install it (apt install yt-dlp)"; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg is required. Install it (apt install ffmpeg)"; exit 1; }

YTDLP_OPTS=( -o "$WORKDIR/%(id)s.%(ext)s" )
if [ -n "$COOKIES_FILE" ]; then
  if [ ! -f "$COOKIES_FILE" ]; then
    echo "Cookies file '$COOKIES_FILE' not found."; exit 1
  fi
  YTDLP_OPTS+=( --cookies "$COOKIES_FILE" )
else
  # Encourage use of cookies-from-browser when possible
  echo "No cookies file supplied. Public reels may download, private/rate-limited content may fail."
fi

set -x
# Try to download (capture exit code)
if ! yt-dlp "${YTDLP_OPTS[@]}" "$URL"; then
  echo "yt-dlp failed to download the reel. Common reasons: login required, rate-limited, or content removed."
  echo "If it's behind a login, provide a cookies.txt file exported from your browser (File → Export Cookies), then re-run: $0 <url> /path/to/cookies.txt"
  exit 2
fi
set +x

# Find downloaded file (mp4 or first file)
VIDEO_PATH=$(ls "$WORKDIR"/*.mp4 2>/dev/null || true)
if [ -z "$VIDEO_PATH" ]; then
  VIDEO_PATH=$(ls "$WORKDIR"/* 2>/dev/null | head -n1 || true)
fi
if [ -z "$VIDEO_PATH" ]; then
  echo "Failed to find downloaded video in $WORKDIR"; exit 3
fi

AUDIO_PATH="$WORKDIR/audio.wav"
echo "Extracting audio to $AUDIO_PATH..."
ffmpeg -y -i "$VIDEO_PATH" -vn -acodec pcm_s16le -ar 16000 -ac 1 "$AUDIO_PATH"

# Python virtualenv inside the workdir for reproducibility
VENV="$WORKDIR/.venv"
if [ ! -d "$VENV" ]; then
  echo "Creating virtualenv at $VENV..."
  python3 -m venv "$VENV"
fi
"$VENV/bin/python" -m pip install --upgrade pip setuptools wheel
# Install light deps only; for Whisper support the user must opt-in later
"$VENV/bin/pip" install --no-input --disable-pip-version-check SpeechRecognition pydub

TRANSCRIPT_PATH="$WORKDIR/transcript.txt"

echo "Transcribing audio..."
"$VENV/bin/python" "$(dirname "$0")/transcribe.py" "$AUDIO_PATH" "$TRANSCRIPT_PATH" --engine google

echo "Done. Outputs in: $WORKDIR"
ls -la "$WORKDIR"

echo "Transcript preview:"
sed -n '1,40p' "$TRANSCRIPT_PATH" || true

# Print next steps
cat <<EOF
Notes:
- If yt-dlp failed with a message about cookies or login, export cookies from your browser and re-run with the cookies file path.
- To use a local Whisper model instead of Google Web Speech API, re-run transcribe.py with --engine whisper (requires optional install).
EOF
