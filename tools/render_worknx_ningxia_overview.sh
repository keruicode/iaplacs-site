#!/usr/bin/env bash

# Render a Ningxia-only T13-T48 hourly precipitation overview from WORK_nx.
# Thirty-six hourly panels remain after the first 12 spin-up hours, so the
# product is intentionally one 6x6 image with no detail pages.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_NX_ROOT="${WORK_NX_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK_nx}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$SCRIPT_DIR/worknx_ningxia_overview}"
NCL_SCRIPT="${NCL_SCRIPT:-$SCRIPT_DIR/rain_worknx_ningxia_hour_bjt.ncl}"
NATIONAL_NCL_SCRIPT="${NATIONAL_NCL_SCRIPT:-$SCRIPT_DIR/rain_worknx_national_hour_bjt.ncl}"
NCL_BIN="${NCL_BIN:-/public/software/apps/ncl_ncarg/ncl630/bin/ncl}"
NCL_ROOT="${NCL_ROOT:-/public/software/apps/ncl_ncarg/ncl630}"
MIN_FILE_AGE_SECONDS="${MIN_FILE_AGE_SECONDS:-1200}"
MIN_WRFOUT_BYTES="${MIN_WRFOUT_BYTES:-20000000000}"
NINGXIA_SHP_FILE="${NINGXIA_SHP_FILE:-$SCRIPT_DIR/SHP/省界_region.shp}"
NINGXIA_PROVINCE_SHP_FILE="${NINGXIA_PROVINCE_SHP_FILE:-$NINGXIA_SHP_FILE}"
NINGXIA_COUNTY_SHP_FILE="${NINGXIA_COUNTY_SHP_FILE:-$SCRIPT_DIR/SHP/ningxia_city_county.shp}"

usage() {
  cat <<'EOF'
Usage: render_worknx_ningxia_overview.sh [--latest | --recent COUNT]

Reads stable WORK_nx wrfout files, renders only hourly T13-T48 Ningxia
panels, and writes one *_combined_overview_6x6_grid.png per run.
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
if [[ ! -d "$WORK_NX_ROOT" ]]; then
  echo "ERROR: WORK_NX_ROOT not found: $WORK_NX_ROOT" >&2
  exit 1
fi
if [[ ! -f "$NCL_SCRIPT" ]]; then
  echo "ERROR: NCL script not found: $NCL_SCRIPT" >&2
  exit 1
fi
if [[ ! -f "$NATIONAL_NCL_SCRIPT" ]]; then
  echo "ERROR: nationwide NCL script not found: $NATIONAL_NCL_SCRIPT" >&2
  exit 1
fi
[[ -x "$NCL_BIN" ]] || { echo "ERROR: ncl is required: $NCL_BIN" >&2; exit 127; }
[[ -d "$NCL_ROOT/lib/ncarg" ]] || { echo "ERROR: NCARG_ROOT is invalid: $NCL_ROOT" >&2; exit 127; }
command -v montage >/dev/null || { echo "ERROR: ImageMagick montage is required" >&2; exit 127; }
command -v convert >/dev/null || { echo "ERROR: ImageMagick convert is required" >&2; exit 127; }
export NCARG_ROOT="$NCL_ROOT"

if [[ -n "$NINGXIA_PROVINCE_SHP_FILE" && ! -f "$NINGXIA_PROVINCE_SHP_FILE" ]]; then
  echo "WARNING: Ningxia province SHP not found, province outline will be skipped: $NINGXIA_PROVINCE_SHP_FILE" >&2
fi
if [[ -n "$NINGXIA_COUNTY_SHP_FILE" && ! -f "$NINGXIA_COUNTY_SHP_FILE" ]]; then
  echo "WARNING: Ningxia city/county SHP not found, city/county outline will be skipped: $NINGXIA_COUNTY_SHP_FILE" >&2
fi

mkdir -p "$OUTPUT_ROOT"
now_epoch="$(date +%s)"
sources=()
while IFS= read -r line; do
  source_epoch="${line%% *}"
  rest="${line#* }"
  source_size="${rest%% *}"
  source_path="${rest#* }"
  source_epoch="${source_epoch%.*}"
  if (( now_epoch - source_epoch < MIN_FILE_AGE_SECONDS )); then
    continue
  fi
  if (( source_size < MIN_WRFOUT_BYTES )); then
    continue
  fi
  sources+=("$source_path")
  [[ "${#sources[@]}" -ge "$count" ]] && break
done < <(
  find "$WORK_NX_ROOT" -maxdepth 4 -type f \
    -name 'wrfout_d01_*' -printf '%T@ %s %p\n' \
    | sort -nr
)

if [[ "${#sources[@]}" -eq 0 ]]; then
  echo "ERROR: no stable WORK_nx wrfout source found" >&2
  exit 1
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

  # Add the valid-time label after NCL rendering. This keeps the label black
  # and independent of the precipitation palette while giving every montage
  # tile the same caption height.
  convert "$panel_path" \
    -gravity North \
    -background white \
    -splice 0x78 \
    -fill black \
    -font Helvetica-Bold \
    -pointsize 70 \
    -annotate +0+7 "$panel_date" \
    "$caption_path"
}

render_source() {
  local source_path="$1" base run_date run_hour run_prefix wrf_dir run_dir panel_dir caption_dir overview
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
  overview="$run_dir/Precip_hourly_WRF_Ningxia_T13_T48_InitUTC_${run_date}_${run_hour}_00_combined_overview_6x6_grid.png"

  mkdir -p "$panel_dir" "$caption_dir"
  echo "Rendering Ningxia T13-T48 panels for $run_prefix from $wrf_dir"
  WORK_NX_WRF_DIR="$wrf_dir" \
    WORK_NX_NINGXIA_PNG_DIR="$panel_dir" \
    NINGXIA_SHP_FILE="$NINGXIA_PROVINCE_SHP_FILE" \
    NINGXIA_PROVINCE_SHP_FILE="$NINGXIA_PROVINCE_SHP_FILE" \
    NINGXIA_COUNTY_SHP_FILE="$NINGXIA_COUNTY_SHP_FILE" \
    "$NCL_BIN" "$NCL_SCRIPT"

  local panels=()
  mapfile -t panels < <(find "$panel_dir" -maxdepth 1 -type f -name '*_rain_hour_*_BJT.png' -print | sort)
  if [[ "${#panels[@]}" -ne 36 ]]; then
    echo "ERROR: expected 36 T13-T48 panels, found ${#panels[@]} for $run_prefix" >&2
    return 1
  fi

  local captioned_panels=()
  for panel in "${panels[@]}"; do
    caption_panel "$panel" "$caption_dir"
    captioned_panels+=("$caption_dir/$(basename "$panel")")
  done

  montage "${captioned_panels[@]}" -tile 6x6 -geometry '100%x100%+2+2' -background white "$overview"
  touch -r "$source_path" "$overview"

  for accum_hours in 12 24; do
    local accum_source accum_overview
    WORK_NX_WRF_DIR="$wrf_dir" \
      WORK_NX_NATIONAL_PNG_DIR="$panel_dir" \
      WORK_NX_NATIONAL_PROVINCE_SHP_FILE="$NINGXIA_PROVINCE_SHP_FILE" \
      RAIN_ACCUM_HOURS="$accum_hours" \
      "$NCL_BIN" "$NATIONAL_NCL_SCRIPT"
    accum_source="$(find "$panel_dir" -maxdepth 1 -type f -name "*_national_accum_$(printf '%02d' "$accum_hours")h_*_BJT.png" | sort | tail -n 1)"
    [[ -n "$accum_source" ]] || { echo "ERROR: missing ${accum_hours}h nationwide Ningxia accumulation for $run_prefix" >&2; return 1; }
    accum_overview="$run_dir/Precip_accum_${accum_hours}h_WRF_Ningxia_T13_T48_InitUTC_${run_date}_${run_hour}_00_combined_overview_1x1_grid.png"
    cp -p "$accum_source" "$accum_overview"
    touch -r "$source_path" "$accum_overview"
  done
  echo "Rendered $overview"
}

for source_path in "${sources[@]}"; do
  render_source "$source_path"
done
