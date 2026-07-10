#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAPS_DIR="$ROOT/data/current/maps"
FORCE="${IAPLACS_OPTIMIZE_FORCE:-0}"

if command -v magick >/dev/null 2>&1; then
  IMAGE_TOOL=(magick)
elif command -v convert >/dev/null 2>&1; then
  IMAGE_TOOL=(convert)
else
  echo "ImageMagick is required (magick or convert)." >&2
  exit 1
fi

optimize_image() {
  local source="$1"
  local max_size="$2"
  local output="${source%.*}.webp"

  if [[ "$FORCE" != "1" && -f "$output" && ! "$source" -nt "$output" ]]; then
    return
  fi

  "${IMAGE_TOOL[@]}" "$source" \
    -resize "${max_size}x${max_size}>" \
    -strip \
    -quality 92 \
    -define webp:method=6 \
    -define webp:use-sharp-yuv=true \
    "$output"
  touch -r "$source" "$output"
  echo "optimized ${output#$ROOT/}"
}

while IFS= read -r -d '' source; do
  optimize_image "$source" 3200
done < <(find "$MAPS_DIR" -type f -path "*/worknx_summary_*/*.png" -print0)

while IFS= read -r -d '' source; do
  optimize_image "$source" 3200
done < <(find "$MAPS_DIR" -type f -path "*/wrf_montage_*/*overview*.png" -print0)

while IFS= read -r -d '' source; do
  optimize_image "$source" 2800
done < <(find "$MAPS_DIR" -type f -path "*/wrf_montage_*/*detail*.png" -print0)
