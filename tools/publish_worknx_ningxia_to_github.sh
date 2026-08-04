#!/usr/bin/env bash

# Render WORK_nx to a Ningxia product through the latest available lead, then pass each
# generated overview to the existing OSS/GitHub publisher.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDERER="${RENDERER:-$SCRIPT_DIR/render_worknx_ningxia_overview.sh}"
PUBLISHER="${PUBLISHER:-$SCRIPT_DIR/publish_worknx_summary_to_github.sh}"
HOURLY_PUBLISHER="${HOURLY_PUBLISHER:-$SCRIPT_DIR/publish_hourly_panels_to_oss.sh}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$SCRIPT_DIR/worknx_ningxia_overview}"

usage() {
  cat <<'EOF'
Usage: publish_worknx_ningxia_to_github.sh [--latest | --recent COUNT | --output-run YYYYMMDD_HH]

Renders Ningxia regional and nationwide products through the latest available
lead, then publishes each matching overview through the existing publisher.
--output-run republishes an already rendered run without running NCL again.
EOF
}

mode="--latest"
count=1
output_run=""
if [[ "${1:-}" == "--recent" ]]; then
  mode="--recent"
  count="${2:-5}"
elif [[ "${1:-}" == "--output-run" ]]; then
  mode="--output-run"
  output_run="${2:-}"
elif [[ -n "${1:-}" && "${1:-}" != "--latest" ]]; then
  usage >&2
  exit 64
fi

if [[ "$mode" != "--output-run" && ! "$count" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: recent count must be a positive integer" >&2
  exit 64
fi
if [[ "$mode" == "--output-run" && ! "$output_run" =~ ^[0-9]{8}_[0-9]{2}$ ]]; then
  echo "ERROR: output run must use YYYYMMDD_HH" >&2
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
if [[ ! -x "$HOURLY_PUBLISHER" ]]; then
  echo "ERROR: hourly publisher is not executable: $HOURLY_PUBLISHER" >&2
  exit 1
fi

if [[ "$mode" == "--recent" ]]; then
  "$RENDERER" --recent "$count"
elif [[ "$mode" == "--latest" ]]; then
  "$RENDERER" --latest
fi

if [[ "$mode" == "--output-run" ]]; then
  mapfile -t sources < <(
    find "$OUTPUT_ROOT/$output_run" -maxdepth 1 -type f \
      -name 'Precip_hourly_WRF_Ningxia_T13_T*_InitUTC_*_combined_overview_*_grid.png' \
      | sort
  )
  count=1
else
  mapfile -t sources < <(
    find "$OUTPUT_ROOT" -mindepth 2 -maxdepth 2 -type f \
      -name 'Precip_hourly_WRF_Ningxia_T13_T*_InitUTC_*_combined_overview_*_grid.png' \
      -printf '%T@ %p\n' \
      | sort -nr \
      | head -n "$count" \
      | cut -d' ' -f2-
  )
fi

if [[ "${#sources[@]}" -ne "$count" ]]; then
  echo "ERROR: expected $count Ningxia overview image(s), found ${#sources[@]}" >&2
  exit 1
fi

for source in "${sources[@]}"; do
  source_dir="$(dirname "$source")"
  run_prefix="$(basename "$source_dir")"
  echo "Publishing Ningxia regional overview: $source"
  IAPLACS_WEBP_FORCE=1 \
    IAPLACS_PREVIEW_FORCE=1 \
    IAPLACS_ASSET_FORCE_UPLOAD=1 \
    WORK_NX_ROOT="$source_dir" \
    SOURCE_IMAGE_GLOB="$(basename "$source")" \
    MIN_FILE_AGE_SECONDS=0 \
    STABILITY_SLEEP_SECONDS=0 \
    "$PUBLISHER"

  mapfile -t national_sources < <(
    find "$source_dir" -maxdepth 1 -type f \
      -name 'Precip_hourly_WRF_AllRain_T13_T*_InitUTC_*_combined_overview_*_grid.png' \
      | sort
  )
  if [[ "${#national_sources[@]}" -gt 0 ]]; then
    echo "Publishing WORK_nx national overview: ${national_sources[0]}"
    IAPLACS_WEBP_FORCE=1 \
      IAPLACS_PREVIEW_FORCE=1 \
      IAPLACS_ASSET_FORCE_UPLOAD=1 \
      WORK_NX_ROOT="$source_dir" \
      SOURCE_IMAGE_GLOB="$(basename "${national_sources[0]}")" \
      MIN_FILE_AGE_SECONDS=0 \
      "$PUBLISHER"
  else
    echo "WARNING: no WORK_nx national overview found beside $source" >&2
  fi

  while IFS= read -r accum_source; do
    [[ -n "$accum_source" ]] || continue
    echo "Publishing Ningxia accumulation: $accum_source"
    IAPLACS_WEBP_FORCE=1 IAPLACS_PREVIEW_FORCE=1 IAPLACS_ASSET_FORCE_UPLOAD=1 WORK_NX_ROOT="$source_dir" SOURCE_IMAGE_GLOB="$(basename "$accum_source")" MIN_FILE_AGE_SECONDS=0 "$PUBLISHER" </dev/null
  done < <(find "$source_dir" -maxdepth 1 -type f -name 'Precip_accum_*h_WRF_Ningxia_T13_T*_InitUTC_*_combined_overview_1x1_grid.png' | sort)

  "$HOURLY_PUBLISHER" \
    --family worknx_summary \
    --run-prefix "$run_prefix" \
    --regional-dir "$source_dir/captioned_t13_t48" \
    --national-dir "$source_dir/national_captioned_t13_t48"
done
