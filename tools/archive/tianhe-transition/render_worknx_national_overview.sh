#!/usr/bin/env bash

# Render a nationwide hourly precipitation overview after the T12 spin-up.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_NX_ROOT="${WORK_NX_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK_nx}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$SCRIPT_DIR/worknx_national_overview}"
NCL_SCRIPT="${NCL_SCRIPT:-$SCRIPT_DIR/rain_worknx_national_hour_bjt.ncl}"
NCL_BIN="${NCL_BIN:-/public/software/apps/ncl_ncarg/ncl630/bin/ncl}"
NCL_ROOT="${NCL_ROOT:-/public/software/apps/ncl_ncarg/ncl630}"
NCDUMP_BIN="${NCDUMP_BIN:-/public/software/apps/conda/latest/bin/ncdump}"
MIN_FILE_AGE_SECONDS="${MIN_FILE_AGE_SECONDS:-1200}"
MIN_WRFOUT_BYTES="${MIN_WRFOUT_BYTES:-8000000000}"
MIN_TIME_COUNT="${MIN_TIME_COUNT:-14}"
NATIONAL_PROVINCE_SHP_FILE="${NATIONAL_PROVINCE_SHP_FILE:-$SCRIPT_DIR/SHP/省界_region.shp}"

usage() {
  cat <<'EOF'
Usage: render_worknx_national_overview.sh [--latest | --recent COUNT | --assemble-existing RUN | --assemble-legacy RUN]

Renders hourly nationwide panels from T13 through the latest available lead.
An output is eligible when rsl.error.0000 ends successfully, or when it has
been stable for 20 minutes and exceeds the configured size threshold.
EOF
}

count=1
existing_run=""
assemble_legacy="0"
if [[ "${1:-}" == "--assemble-existing" ]]; then
  existing_run="${2:-}"
elif [[ "${1:-}" == "--assemble-legacy" ]]; then
  existing_run="${2:-}"
  assemble_legacy="1"
elif [[ "${1:-}" == "--recent" ]]; then
  count="${2:-5}"
elif [[ -n "${1:-}" && "${1:-}" != "--latest" ]]; then
  usage >&2
  exit 64
fi

[[ "$count" =~ ^[1-9][0-9]*$ ]] || { echo "ERROR: recent count must be positive" >&2; exit 64; }
[[ "$MIN_TIME_COUNT" =~ ^[1-9][0-9]*$ ]] || { echo "ERROR: MIN_TIME_COUNT must be positive" >&2; exit 64; }
[[ -z "$existing_run" || "$existing_run" =~ ^[0-9]{8}_[0-9]{2}$ ]] || { echo "ERROR: existing run must be YYYYMMDD_HH" >&2; exit 64; }
[[ -d "$WORK_NX_ROOT" ]] || { echo "ERROR: WORK_nx not found: $WORK_NX_ROOT" >&2; exit 1; }
[[ -f "$NCL_SCRIPT" ]] || { echo "ERROR: NCL script not found: $NCL_SCRIPT" >&2; exit 1; }
[[ -x "$NCL_BIN" ]] || { echo "ERROR: ncl is required: $NCL_BIN" >&2; exit 127; }
[[ -d "$NCL_ROOT/lib/ncarg" ]] || { echo "ERROR: NCARG_ROOT is invalid: $NCL_ROOT" >&2; exit 127; }
command -v montage >/dev/null || { echo "ERROR: ImageMagick montage is required" >&2; exit 127; }
command -v convert >/dev/null || { echo "ERROR: ImageMagick convert is required" >&2; exit 127; }
[[ -x "$NCDUMP_BIN" ]] || { echo "ERROR: ncdump is required: $NCDUMP_BIN" >&2; exit 127; }
export NCARG_ROOT="$NCL_ROOT"

if [[ -n "$NATIONAL_PROVINCE_SHP_FILE" && ! -f "$NATIONAL_PROVINCE_SHP_FILE" ]]; then
  echo "WARNING: nationwide province SHP not found, province outline will be skipped: $NATIONAL_PROVINCE_SHP_FILE" >&2
fi

mkdir -p "$OUTPUT_ROOT"
wrf_time_count() {
  "$NCDUMP_BIN" -h "$1" 2>/dev/null | awk '/Time = UNLIMITED/ && !seen { gsub(/[^0-9]/, "", $0); print; seen=1 }'
}

wrf_completed_successfully() {
  local rsl_file
  rsl_file="$(dirname "$1")/rsl.error.0000"
  [[ -f "$rsl_file" ]] && tail -n 200 "$rsl_file" | grep -q 'SUCCESS COMPLETE WRF'
}

sources=()
if [[ -z "$existing_run" ]]; then
  now_epoch="$(date +%s)"
  while IFS= read -r line; do
    source_epoch="${line%% *}"
    rest="${line#* }"
    source_size="${rest%% *}"
    source_path="${rest#* }"
    source_epoch="${source_epoch%.*}"
    (( source_size >= MIN_WRFOUT_BYTES )) || continue
    time_count="$(wrf_time_count "$source_path")"
    [[ "$time_count" =~ ^[0-9]+$ ]] && (( time_count >= MIN_TIME_COUNT )) || continue
    if ! wrf_completed_successfully "$source_path"; then
      (( now_epoch - source_epoch >= MIN_FILE_AGE_SECONDS )) || continue
    fi
    sources+=("$source_path")
    [[ "${#sources[@]}" -ge "$count" ]] && break
  done < <(
    find "$WORK_NX_ROOT" -maxdepth 4 -type f \
      -name 'wrfout_d01_*' -printf '%T@ %s %p\n' | sort -nr
  )

  [[ "${#sources[@]}" -gt 0 ]] || { echo "ERROR: no stable WORK_nx wrfout source found" >&2; exit 1; }
fi

caption_panel() {
  local panel_path="$1" caption_dir="$2" panel_name panel_date caption_path
  panel_name="$(basename "$panel_path")"
  if [[ ! "$panel_name" =~ _rain_hour_([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})-([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})_BJT\.png$ ]]; then
    echo "ERROR: cannot parse panel date from $panel_name" >&2
    return 1
  fi
  panel_date="${BASH_REMATCH[2]}-${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:00-${BASH_REMATCH[8]}:00"
  caption_path="$caption_dir/$panel_name"
  convert "$panel_path" \
    -trim +repage \
    -gravity North \
    -background white \
    -splice 0x92 \
    -fill black \
    -font Times-Bold \
    -stroke black \
    -strokewidth 1 \
    -pointsize 88 \
    -annotate +0+14 "$panel_date" \
    "$caption_path"
}

caption_panel_legacy() {
  caption_panel "$@"
}

render_source() {
  local source_path="$1" base run_date run_hour run_prefix wrf_dir run_dir panel_dir caption_dir overview mosaic init_bjt init_label time_count last_lead panel_count overview_rows overview_grid
  base="$(basename "$source_path")"
  if [[ ! "$base" =~ wrfout_d01_([0-9]{4})-([0-9]{2})-([0-9]{2})_([0-9]{2}):[0-9]{2}:[0-9]{2} ]]; then
    echo "ERROR: cannot parse run time from $base" >&2
    return 1
  fi
  run_date="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]}"
  run_hour="${BASH_REMATCH[4]}"
  run_prefix="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}_${run_hour}"
  wrf_dir="$(dirname "$source_path")"
  run_dir="$OUTPUT_ROOT/$run_prefix"
  panel_dir="$run_dir/hourly_t13_t48"
  caption_dir="$run_dir/captioned_t13_t48"
  init_bjt="$(TZ=Asia/Shanghai date -d "${run_date} ${run_hour}:00 UTC" '+%Y-%m-%d %H:%M BJT')"
  init_label="Forecast Initialization: $init_bjt"
  time_count="$(wrf_time_count "$source_path")"
  [[ "$time_count" =~ ^[0-9]+$ ]] && (( time_count >= MIN_TIME_COUNT )) || {
    echo "ERROR: T13 is not available in $source_path" >&2
    return 1
  }
  last_lead=$((time_count - 1))

  mkdir -p "$panel_dir" "$caption_dir"
  echo "Rendering nationwide T13-T${last_lead} panels for $run_prefix from $wrf_dir"
  WORK_NX_WRF_DIR="$wrf_dir" \
    WORK_NX_NATIONAL_PNG_DIR="$panel_dir" \
    WORK_NX_NATIONAL_PROVINCE_SHP_FILE="$NATIONAL_PROVINCE_SHP_FILE" \
    "$NCL_BIN" "$NCL_SCRIPT"

  local panels=()
  mapfile -t panels < <(find "$panel_dir" -maxdepth 1 -type f -name '*_national_rain_hour_*_BJT.png' -print | sort)
  panel_count="${#panels[@]}"
  if (( panel_count != last_lead - 12 )); then
    echo "ERROR: expected $((last_lead - 12)) T13-T${last_lead} panels, found ${panel_count} for $run_prefix" >&2
    return 1
  fi
  overview_rows=$(((panel_count + 5) / 6))
  overview_grid="6x${overview_rows}"
  overview="$run_dir/Precip_hourly_WRF_AllRain_T13_T${last_lead}_InitUTC_${run_date}_${run_hour}_00_combined_overview_${overview_grid}_grid.png"
  mosaic="$run_dir/.combined_overview_${overview_grid}_grid.mosaic.png"

  local captioned_panels=() caption_function="caption_panel"
  [[ "$assemble_legacy" == "1" ]] && caption_function="caption_panel_legacy"
  for panel in "${panels[@]}"; do
    "$caption_function" "$panel" "$caption_dir"
    captioned_panels+=("$caption_dir/$(basename "$panel")")
  done

  montage "${captioned_panels[@]}" -tile "$overview_grid" -geometry '100%x100%+2+2' -background white "$mosaic"
  convert "$mosaic" \
    -gravity North \
    -background white \
    -splice 0x160 \
    -fill black \
    -font Times-Bold \
    -stroke black \
    -strokewidth 1 \
    -pointsize 132 \
    -annotate +0+24 "$init_label" \
    "$overview"
  rm -f "$mosaic"
  touch -r "$source_path" "$overview"
  echo "Rendered $overview"
}

assemble_existing() {
  local run_prefix="$1" run_date run_hour run_dir panel_dir caption_dir overview mosaic init_bjt init_label panel_count last_lead overview_rows overview_grid
  run_date="${run_prefix:0:4}-${run_prefix:4:2}-${run_prefix:6:2}"
  run_hour="${run_prefix:9:2}"
  run_dir="$OUTPUT_ROOT/$run_prefix"
  panel_dir="$run_dir/hourly_t13_t48"
  caption_dir="$run_dir/captioned_t13_t48"
  init_bjt="$(TZ=Asia/Shanghai date -d "${run_date} ${run_hour}:00 UTC" '+%Y-%m-%d %H:%M BJT')"
  init_label="Forecast Initialization: $init_bjt"

  mapfile -t panels < <(find "$panel_dir" -maxdepth 1 -type f -name '*_national_rain_hour_*_BJT.png' -print | sort)
  panel_count="${#panels[@]}"
  (( panel_count > 0 )) || { echo "ERROR: no archived panels found for $run_prefix" >&2; return 1; }
  last_lead=$((panel_count + 12))
  overview_rows=$(((panel_count + 5) / 6))
  overview_grid="6x${overview_rows}"
  overview="$run_dir/Precip_hourly_WRF_AllRain_T13_T${last_lead}_InitUTC_${run_date}_${run_hour}_00_combined_overview_${overview_grid}_grid.png"
  mosaic="$run_dir/.combined_overview_${overview_grid}_grid.mosaic.png"

  mkdir -p "$caption_dir"
  local captioned_panels=()
  for panel in "${panels[@]}"; do
    caption_panel "$panel" "$caption_dir"
    captioned_panels+=("$caption_dir/$(basename "$panel")")
  done

  montage "${captioned_panels[@]}" -tile "$overview_grid" -geometry '100%x100%+2+2' -background white "$mosaic"
  convert "$mosaic" \
    -gravity North \
    -background white \
    -splice 0x160 \
    -fill black \
    -font "times.ttf" \
    -stroke none \
    -pointsize 132 \
    -annotate +0+24 "$init_label" \
    "$overview"
  rm -f "$mosaic"
  echo "Reassembled archived nationwide overview $overview"
}

if [[ -n "$existing_run" ]]; then
  assemble_existing "$existing_run"
else
  for source_path in "${sources[@]}"; do
    render_source "$source_path"
  done
fi
