#!/usr/bin/env bash
set -euo pipefail

START_SECONDS=55
FADE_IN_SECONDS=0.3
BITRATE=96k

FFMPEG="${FFMPEG:-ffmpeg}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/assets/song.mp3"
OUT_DIR="$ROOT/public/audio"
OUT="$OUT_DIR/song.m4a"

command -v "$FFMPEG" >/dev/null || { echo "ffmpeg not found (brew install ffmpeg)" >&2; exit 1; }
[ -f "$SRC" ] || { echo "Missing $SRC" >&2; exit 1; }

if "$FFMPEG" -hide_banner -encoders 2>/dev/null | grep -q ' aac_at '; then
  encoder=aac_at
else
  encoder=aac
fi

fade_filter=()
if awk -v f="$FADE_IN_SECONDS" 'BEGIN { exit !(f > 0) }'; then
  fade_filter=(-af "afade=t=in:st=0:d=${FADE_IN_SECONDS}")
fi

mkdir -p "$OUT_DIR"
tmp="$OUT_DIR/.song.tmp.m4a"
trap 'rm -f "$tmp"' EXIT

"$FFMPEG" -nostdin -v error -y -ss "$START_SECONDS" -i "$SRC" \
  -map 0:a:0 -vn -map_metadata -1 \
  ${fade_filter[@]+"${fade_filter[@]}"} \
  -c:a "$encoder" -b:a "$BITRATE" -ac 2 \
  -movflags +faststart \
  "$tmp"
mv "$tmp" "$OUT"
trap - EXIT

echo "Wrote public/audio/song.m4a ($(du -h "$OUT" | cut -f1)), starting at ${START_SECONDS}s, encoder $encoder."
