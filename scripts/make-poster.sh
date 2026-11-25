#!/usr/bin/env bash
set -euo pipefail

WIDTHS=(800 1200 1600 2400)
OG_WIDTH=1200
QUALITY=82
POSTER_MARGIN=50

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/assets/poster.png"
OUT="$ROOT/public/images"
HTML="$ROOT/public/index.html"

[ -f "$SRC" ] || { echo "Missing $SRC" >&2; exit 1; }
grep -q 'id="poster-image"' "$HTML" || { echo "No img with id=\"poster-image\" in index.html" >&2; exit 1; }

src_w="$(sips -g pixelWidth "$SRC" | awk '/pixelWidth/ { print $2 }')"
src_h="$(sips -g pixelHeight "$SRC" | awk '/pixelHeight/ { print $2 }')"
echo "Source poster: ${src_w}x${src_h}"

if ffmpeg_bin="$(command -v ffmpeg)"; then
  alpha_min="$("$ffmpeg_bin" -nostdin -hide_banner -i "$SRC" \
    -vf "alphaextract,signalstats,metadata=print:key=lavfi.signalstats.YMIN" \
    -f null - 2>&1 | awk -F= '/YMIN/ { print $2 }' || true)"
  if [ -n "$alpha_min" ] && [ "$alpha_min" -lt 255 ]; then
    echo "Warning: poster has transparent areas; they will not be transparent in the JPEGs." >&2
  fi
fi

rm -rf "$OUT"
mkdir -p "$OUT"

resize_to_jpeg() {
  sips -s format jpeg -s formatOptions "$QUALITY" --resampleWidth "$1" "$SRC" --out "$2" >/dev/null
}

srcset=()
for w in "${WIDTHS[@]}"; do
  [ "$w" -gt "$src_w" ] && w="$src_w"
  file="poster-$w.jpg"
  [ -f "$OUT/$file" ] && continue
  resize_to_jpeg "$w" "$OUT/$file"
  srcset+=("images/$file ${w}w")
  echo "public/images/$file  $(du -h "$OUT/$file" | cut -f1)"
done

og_w=$(( OG_WIDTH < src_w ? OG_WIDTH : src_w ))
resize_to_jpeg "$og_w" "$OUT/og.jpg"
echo "public/images/og.jpg  $(du -h "$OUT/og.jpg" | cut -f1)"

ratio="$(awk -v w="$src_w" -v h="$src_h" 'BEGIN { printf "%.4f", w / h }')"
sizes="min(calc(100vw - $((POSTER_MARGIN * 2))px), calc((100vh - $((POSTER_MARGIN * 2))px) * $ratio))"
largest="${srcset[${#srcset[@]}-1]%% *}"
srcset_attr="$(IFS=,; echo "${srcset[*]}" | sed 's/,/, /g')"

POSTER_SRC="$largest" POSTER_SRCSET="$srcset_attr" POSTER_SIZES="$sizes" \
  perl -0pi -e '
    s{(<img\b[^>]*\bid="poster-image"[^>]*>)}{
      my $tag = $1;
      $tag =~ s/\bsrc="[^"]*"/src="$ENV{POSTER_SRC}"/;
      $tag =~ s/\bsrcset="[^"]*"/srcset="$ENV{POSTER_SRCSET}"/;
      $tag =~ s/\bsizes="[^"]*"/sizes="$ENV{POSTER_SIZES}"/;
      $tag
    }se;
  ' "$HTML"

echo "Updated poster srcset/sizes in public/index.html (aspect ratio $ratio)."
