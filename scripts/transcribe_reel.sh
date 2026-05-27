#!/usr/bin/env bash
set -euo pipefail

# Usage: ./transcribe_reel.sh <instagram_reel_url>
# Downloads an Instagram reel, extracts audio, and transcribes to text.

URL="$1"
WORKDIR="$(pwd)/output_$(date +%s)"
mkdir -p "$WORKDIR"

command -v yt-dlp >/dev/null 2>&1 || { echo "yt-dlp is required. Install it (apt install yt-dlp)"; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg is required. Install it (apt install ffmpeg)"; exit 1; }

echo "Downloading video..."
yt-dlp -f best -o "$WORKDIR/%(id)s.%(ext)s" "$URL"
VIDEO_PATH=$(ls "$WORKDIR"/*.mp4 2>/dev/null || true)
if [ -z "$VIDEO_PATH" ]; then
  VIDEO_PATH=$(ls "$WORKDIR"/* 2>/dev/null | head -n1)
fi
if [ -z "$VIDEO_PATH" ]; then
  echo "Failed to find downloaded video in $WORKDIR"; exit 1
fi

AUDIO_PATH="$WORKDIR/audio.wav"
echo "Extracting audio to $AUDIO_PATH..."
ffmpeg -y -i "$VIDEO_PATH" -vn -acodec pcm_s16le -ar 16000 -ac 1 "$AUDIO_PATH" >/dev/null 2>&1

# Python virtualenv
VENV="$WORKDIR/.venv"
if [ ! -d "$VENV" ]; then
  echo "Creating virtualenv..."
  python3 -m venv "$VENV"
fi
"$VENV/bin/python" -m pip install --upgrade pip >/dev/null
"$VENV/bin/pip" install --no-input --disable-pip-version-check SpeechRecognition pydub >/dev/null

echo "Transcribing audio..."
"$VENV/bin/python" "$(dirname "$0")/transcribe.py" "$AUDIO_PATH" "$WORKDIR/transcript.txt"

echo "Done. Outputs in: $WORKDIR"
ls -la "$WORKDIR"

echo "Transcript preview:"
sed -n '1,20p' "$WORKDIR/transcript.txt" || true
