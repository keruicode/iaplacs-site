#!/usr/bin/env bash

# Render WORK_nx to a Ningxia product through the latest available lead, then pass each
# generated overview to the existing OSS/GitHub publisher.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDERER="${RENDERER:-$SCRIPT_DIR/render_worknx_ningxia_overview.sh}"
PUBLISHER="${PUBLISHER:-$SCRIPT_DIR/publish_worknx_summary_to_github.sh}"
HOURLY_PUBLISHER="${HOURLY_PUBLISHER:-$SCRIPT_DIR/publish_hourly_panels_to_oss.sh}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$SCRIPT_DIR/worknx_ningxia_overview}"
SERVICE_LABEL="${SERVICE_LABEL:-Ningxia}"
SERVICE_FILE_TOKEN="${SERVICE_FILE_TOKEN:-Ningxia}"
PUBLISH_FAMILY="${PUBLISH_FAMILY:-worknx_summary}"

case "$PUBLISH_FAMILY" in
  worknx_summary) HAIL_FRAME_ID="ningxia_hail_warning" ;;
  workxj_summary) HAIL_FRAME_ID="xinjiang_hail_warning" ;;
  *) HAIL_FRAME_ID="" ;;
esac

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

# Rendering removes stale panels for the selected run before redrawing. Keep
# cron, the hourly auditor, and the BJT 06 early snapshot from cleaning the
# same service output at the same time.
mkdir -p "$OUTPUT_ROOT"
PUBLISH_LOCK_FILE="${PUBLISH_LOCK_FILE:-$OUTPUT_ROOT/.publish.lock}"
PUBLISH_LOCK_WAIT_SECONDS="${PUBLISH_LOCK_WAIT_SECONDS:-14400}"
exec 7>"$PUBLISH_LOCK_FILE"
if ! flock -w "$PUBLISH_LOCK_WAIT_SECONDS" 7; then
  echo "ERROR: timed out waiting for $SERVICE_LABEL publication lock: $PUBLISH_LOCK_FILE" >&2
  exit 75
fi

if [[ "$mode" == "--recent" ]]; then
  "$RENDERER" --recent "$count"
elif [[ "$mode" == "--latest" ]]; then
  "$RENDERER" --latest
fi

if [[ "$mode" == "--output-run" ]]; then
  mapfile -t sources < <(
    find "$OUTPUT_ROOT/$output_run" -maxdepth 1 -type f \
      -name "Precip_hourly_WRF_${SERVICE_FILE_TOKEN}_T13_T*_InitUTC_*_combined_overview_*_grid.png" \
      | sort
  )
  count=1
else
  mapfile -t sources < <(
    find "$OUTPUT_ROOT" -mindepth 2 -maxdepth 2 -type f \
      -name "Precip_hourly_WRF_${SERVICE_FILE_TOKEN}_T13_T*_InitUTC_*_combined_overview_*_grid.png" \
      -printf '%T@ %p\n' \
      | sort -nr \
      | head -n "$count" \
      | cut -d' ' -f2-
  )
fi

if [[ "${#sources[@]}" -ne "$count" ]]; then
  echo "ERROR: expected $count $SERVICE_LABEL overview image(s), found ${#sources[@]}" >&2
  exit 1
fi

for source in "${sources[@]}"; do
  source_dir="$(dirname "$source")"
  run_prefix="$(basename "$source_dir")"
  echo "Publishing $SERVICE_LABEL regional overview: $source"
  IAPLACS_WEBP_FORCE=1 \
    IAPLACS_PREVIEW_FORCE=1 \
    IAPLACS_ASSET_FORCE_UPLOAD=1 \
    WORK_NX_ROOT="$source_dir" \
    PUBLISH_FAMILY="$PUBLISH_FAMILY" \
    SOURCE_LABEL="$SERVICE_LABEL" \
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
    echo "Publishing $SERVICE_LABEL China-sector overview: ${national_sources[0]}"
    IAPLACS_WEBP_FORCE=1 \
      IAPLACS_PREVIEW_FORCE=1 \
      IAPLACS_ASSET_FORCE_UPLOAD=1 \
      WORK_NX_ROOT="$source_dir" \
      PUBLISH_FAMILY="$PUBLISH_FAMILY" \
      SOURCE_LABEL="$SERVICE_LABEL" \
      SOURCE_IMAGE_GLOB="$(basename "${national_sources[0]}")" \
      MIN_FILE_AGE_SECONDS=0 \
      "$PUBLISHER"
  else
    echo "WARNING: no $SERVICE_LABEL China-sector overview found beside $source" >&2
  fi

  if [[ -n "$HAIL_FRAME_ID" ]]; then
    mapfile -t frozen_sources < <(
      find "$source_dir" -maxdepth 1 -type f \
        -name "Precip_hourly_WRF_${SERVICE_FILE_TOKEN}Frozen_T13_T*_InitUTC_*_combined_overview_*_grid.png" \
        | sort
    )
    if [[ "${#frozen_sources[@]}" -gt 0 ]]; then
      echo "Publishing $SERVICE_LABEL hail-warning overview: ${frozen_sources[0]}"
      IAPLACS_WEBP_FORCE=1 \
        IAPLACS_PREVIEW_FORCE=1 \
        IAPLACS_ASSET_FORCE_UPLOAD=1 \
        WORK_NX_ROOT="$source_dir" \
        PUBLISH_FAMILY="$PUBLISH_FAMILY" \
        SOURCE_LABEL="$SERVICE_LABEL hail warning" \
        SOURCE_IMAGE_GLOB="$(basename "${frozen_sources[0]}")" \
        MIN_FILE_AGE_SECONDS=0 \
        "$PUBLISHER"
    else
      echo "WARNING: no $SERVICE_LABEL hail-warning overview found beside $source" >&2
    fi
  fi

  while IFS= read -r accum_source; do
    [[ -n "$accum_source" ]] || continue
    echo "Publishing $SERVICE_LABEL accumulation: $accum_source"
    IAPLACS_WEBP_FORCE=1 IAPLACS_PREVIEW_FORCE=1 IAPLACS_ASSET_FORCE_UPLOAD=1 WORK_NX_ROOT="$source_dir" PUBLISH_FAMILY="$PUBLISH_FAMILY" SOURCE_LABEL="$SERVICE_LABEL" SOURCE_IMAGE_GLOB="$(basename "$accum_source")" MIN_FILE_AGE_SECONDS=0 "$PUBLISHER" </dev/null
  done < <(find "$source_dir" -maxdepth 1 -type f -name "Precip_accum_*h_WRF_${SERVICE_FILE_TOKEN}_T13_T*_InitUTC_*_combined_overview_1x1_grid.png" | sort)

  if [[ -n "$HAIL_FRAME_ID" && -d "$source_dir/frozen_captioned_t13_t48" ]]; then
    "$HOURLY_PUBLISHER" \
      --family "$PUBLISH_FAMILY" \
      --run-prefix "$run_prefix" \
      --regional-dir "$source_dir/captioned_t13_t48" \
      --national-dir "$source_dir/national_captioned_t13_t48" \
      --extra-id "$HAIL_FRAME_ID" \
      --extra-dir "$source_dir/frozen_captioned_t13_t48"
  else
    "$HOURLY_PUBLISHER" \
      --family "$PUBLISH_FAMILY" \
      --run-prefix "$run_prefix" \
      --regional-dir "$source_dir/captioned_t13_t48" \
      --national-dir "$source_dir/national_captioned_t13_t48"
  fi
done
