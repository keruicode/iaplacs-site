#!/usr/bin/env bash

# Render WORK_nx to a Ningxia-only T13-T48 6x6 product, then pass each
# generated overview to the existing OSS/GitHub publisher.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDERER="${RENDERER:-$SCRIPT_DIR/render_worknx_ningxia_overview.sh}"
PUBLISHER="${PUBLISHER:-$SCRIPT_DIR/publish_worknx_summary_to_github.sh}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$SCRIPT_DIR/worknx_ningxia_overview}"

usage() {
  cat <<'EOF'
Usage: publish_worknx_ningxia_to_github.sh [--latest | --recent COUNT]

Renders Ningxia T13-T48 regional 6x6 products, then publishes each matching
overview through the existing WORK_nx OSS/GitHub publisher.
EOF
}

mode="--latest"
count=1
if [[ "${1:-}" == "--recent" ]]; then
  mode="--recent"
  count="${2:-5}"
elif [[ -n "${1:-}" && "${1:-}" != "--latest" ]]; then
  usage >&2
  exit 64
fi

if ! [[ "$count" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: recent count must be a positive integer" >&2
  exit 64
fi
if [[ ! -x "$RENDERER" ]]; then
  echo "ERROR: renderer is not executable: $RENDERER" >&2
  exit 1
fi
if [[ ! -x "$PUBLISHER" ]]; then
  echo "ERROR: publisher is not executable: $PUBLISHER" >&2
  exit 1
fi

if [[ "$mode" == "--recent" ]]; then
  "$RENDERER" --recent "$count"
else
  "$RENDERER" --latest
fi

mapfile -t sources < <(
  find "$OUTPUT_ROOT" -mindepth 2 -maxdepth 2 -type f \
    -name 'Precip_hourly_WRF_Ningxia_T13_T48_InitUTC_*_combined_overview_6x6_grid.png' \
    -printf '%T@ %p\n' \
    | sort -nr \
    | head -n "$count" \
    | cut -d' ' -f2-
)

if [[ "${#sources[@]}" -ne "$count" ]]; then
  echo "ERROR: expected $count Ningxia overview image(s), found ${#sources[@]}" >&2
  exit 1
fi

for source in "${sources[@]}"; do
  echo "Publishing Ningxia regional overview: $source"
  IAPLACS_WEBP_FORCE=1 \
    IAPLACS_PREVIEW_FORCE=1 \
    IAPLACS_ASSET_FORCE_UPLOAD=1 \
    WORK_NX_ROOT="$(dirname "$source")" \
    SOURCE_IMAGE_GLOB="$(basename "$source")" \
    MIN_FILE_AGE_SECONDS=0 \
    "$PUBLISHER"
done
