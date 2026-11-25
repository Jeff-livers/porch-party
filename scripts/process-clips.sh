#!/usr/bin/env bash
set -euo pipefail

MAX_SECONDS=3
MIN_SECONDS=1
WIDTH=854
HEIGHT=480
CRF=27

CONTRAST=0.95
BRIGHTNESS=0.015
SATURATION=0.92
WARMTH=0.02
CHROMA_SHIFT_PX=1
BLUR_SIGMA=0

FFMPEG="${FFMPEG:-ffmpeg}"
FFPROBE="${FFPROBE:-ffprobe}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RAW="$ROOT/raw"
OUT="$ROOT/public/clips"
TMP="$ROOT/.clips.tmp"

command -v "$FFMPEG" >/dev/null || { echo "ffmpeg not found (brew install ffmpeg)" >&2; exit 1; }
command -v "$FFPROBE" >/dev/null || { echo "ffprobe not found (brew install ffmpeg)" >&2; exit 1; }
[ -d "$RAW" ] || { echo "No raw/ folder at $RAW" >&2; exit 1; }

is_nonzero() { awk -v n="$1" 'BEGIN { exit !(n != 0) }'; }
negate() { awk -v n="$1" 'BEGIN { print -n }'; }

tape_look="eq=contrast=${CONTRAST}:brightness=${BRIGHTNESS}:saturation=${SATURATION}"
is_nonzero "$WARMTH" && tape_look+=",colorbalance=rs=${WARMTH}:bs=$(negate "$WARMTH")"
is_nonzero "$CHROMA_SHIFT_PX" && tape_look+=",rgbashift=rh=${CHROMA_SHIFT_PX}:bh=$(negate "$CHROMA_SHIFT_PX")"
is_nonzero "$BLUR_SIGMA" && tape_look+=",gblur=sigma=${BLUR_SIGMA}"
echo "Tape look: $tape_look"

rm -rf "$TMP"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

shopt -s nullglob nocaseglob
sources=("$RAW"/*.mp4 "$RAW"/*.mov "$RAW"/*.m4v)
shopt -u nocaseglob

kept=()
skipped=0
for src in "${sources[@]}"; do
  name="$(basename "${src%.*}")"
  duration="$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$src")"

  if awk -v d="$duration" -v min="$MIN_SECONDS" 'BEGIN { exit !(d < min) }'; then
    printf 'skip  %-24s %6.2fs (under %ss)\n' "$name" "$duration" "$MIN_SECONDS"
    skipped=$((skipped + 1))
    continue
  fi

  printf 'clip  %-24s %6.2fs\n' "$name" "$duration"
  "$FFMPEG" -nostdin -v error -y -i "$src" \
    -map 0:v:0 -an -sn -dn -map_metadata -1 \
    -t "$MAX_SECONDS" \
    -vf "scale=${WIDTH}:${HEIGHT}:flags=bicubic,setsar=1,${tape_look},format=yuv420p" \
    -c:v libx264 -preset slow -crf "$CRF" -profile:v high -level 3.1 \
    -movflags +faststart \
    "$TMP/$name.mp4"
  kept+=("$name.mp4")
done

if [ "${#kept[@]}" -eq 0 ]; then
  echo "No clips at least ${MIN_SECONDS}s long in raw/; leaving public/clips/ untouched." >&2
  exit 1
fi

{
  printf '{\n  "clips": [\n'
  for i in "${!kept[@]}"; do
    sep=","; [ "$i" -eq $((${#kept[@]} - 1)) ] && sep=""
    file="${kept[$i]//\\/\\\\}"; file="${file//\"/\\\"}"
    printf '    "clips/%s"%s\n' "$file" "$sep"
  done
  printf '  ]\n}\n'
} > "$TMP/clips.json"

rm -rf "$OUT"
mv "$TMP" "$OUT"
trap - EXIT

echo
echo "Wrote ${#kept[@]} clips (skipped $skipped) to public/clips/, total $(du -sh "$OUT" | cut -f1)."
