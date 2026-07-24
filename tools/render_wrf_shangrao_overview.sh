#!/usr/bin/env bash

# Render the completed WORK WRF output into the Shangrao overview and three
# readable 12-panel detail pages used by the Shangrao service.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_SHANGRAO_ROOT="${WORK_SHANGRAO_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$SCRIPT_DIR/shangrao_overview}"
NCL_SCRIPT="${NCL_SCRIPT:-$SCRIPT_DIR/rain_wrf_shangrao_hour_bjt.ncl}"
NCL_BIN="${NCL_BIN:-/public/software/apps/ncl_ncarg/ncl630/bin/ncl}"
NCL_ROOT="${NCL_ROOT:-/public/software/apps/ncl_ncarg/ncl630}"
MIN_FILE_AGE_SECONDS="${MIN_FILE_AGE_SECONDS:-1200}"
MIN_WRFOUT_BYTES="${MIN_WRFOUT_BYTES:-20000000000}"
SHANGRAO_PROVINCE_SHP_FILE="${SHANGRAO_PROVINCE_SHP_FILE:-$SCRIPT_DIR/SHP/省界_region.shp}"
SHANGRAO_COUNTY_SHP_FILE="${SHANGRAO_COUNTY_SHP_FILE:-$SCRIPT_DIR/SHP/shangrao_city_county.shp}"

usage() {
  cat <<'EOF'
Usage: render_wrf_shangrao_overview.sh [--latest]

Reads one stable WORK wrfout file, renders hourly T13-T48 Shangrao panels,
then writes one 6x6 overview and three 4x3 detail mosaics.
EOF
}

if [[ -n "${1:-}" && "${1:-}" != "--latest" ]]; then
  usage >&2
  exit 64
fi

[[ -d "$WORK_SHANGRAO_ROOT" ]] || { echo "ERROR: WORK not found: $WORK_SHANGRAO_ROOT" >&2; exit 1; }
[[ -f "$NCL_SCRIPT" ]] || { echo "ERROR: NCL script not found: $NCL_SCRIPT" >&2; exit 1; }
[[ -x "$NCL_BIN" ]] || { echo "ERROR: ncl is required: $NCL_BIN" >&2; exit 127; }
[[ -d "$NCL_ROOT/lib/ncarg" ]] || { echo "ERROR: NCARG_ROOT is invalid: $NCL_ROOT" >&2; exit 127; }
command -v montage >/dev/null || { echo "ERROR: ImageMagick montage is required" >&2; exit 127; }
export NCARG_ROOT="$NCL_ROOT"

if [[ -n "$SHANGRAO_PROVINCE_SHP_FILE" && ! -f "$SHANGRAO_PROVINCE_SHP_FILE" ]]; then
  echo "WARNING: Shangrao province SHP not found, province outline will be skipped: $SHANGRAO_PROVINCE_SHP_FILE" >&2
fi
if [[ ! -f "$SHANGRAO_COUNTY_SHP_FILE" ]]; then
  echo "WARNING: Shangrao city/county SHP not found, city/county outline will be skipped: $SHANGRAO_COUNTY_SHP_FILE" >&2
fi

now_epoch="$(date +%s)"
source_path=""
while IFS= read -r line; do
  source_epoch="${line%% *}"
  rest="${line#* }"
  source_size="${rest%% *}"
  source_path="${rest#* }"
  source_epoch="${source_epoch%.*}"
  (( now_epoch - source_epoch >= MIN_FILE_AGE_SECONDS )) || continue
  (( source_size >= MIN_WRFOUT_BYTES )) || continue
  break
done < <(
  find "$WORK_SHANGRAO_ROOT" -maxdepth 4 -type f -name 'wrfout_d01_*' \
    -printf '%T@ %s %p\n' | sort -nr
)

[[ -n "$source_path" ]] || { echo "ERROR: no stable WORK wrfout source found" >&2; exit 1; }

base="$(basename "$source_path")"
if [[ ! "$base" =~ wrfout_d01_([0-9]{4})-([0-9]{2})-([0-9]{2})_([0-9]{2}):[0-9]{2}:[0-9]{2} ]]; then
  echo "ERROR: cannot parse run time from $base" >&2
  exit 1
fi
run_date="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]}"
run_hour="${BASH_REMATCH[4]}"
run_prefix="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}_${run_hour}"
wrf_dir="$(dirname "$source_path")"
run_dir="$OUTPUT_ROOT/$run_prefix"
panel_dir="$run_dir/hourly_t13_t48"
overview="$run_dir/${run_prefix}_combined_overview_6x6_grid.png"
detail_prefix="$run_dir/${run_prefix}_combined_detail_p"

mkdir -p "$panel_dir"
echo "Rendering Shangrao T13-T48 panels for $run_prefix from $wrf_dir"
SHANGRAO_WRF_DIR="$wrf_dir" \
  SHANGRAO_PNG_DIR="$panel_dir" \
  SHANGRAO_PROVINCE_SHP_FILE="$SHANGRAO_PROVINCE_SHP_FILE" \
  SHANGRAO_COUNTY_SHP_FILE="$SHANGRAO_COUNTY_SHP_FILE" \
  "$NCL_BIN" "$NCL_SCRIPT"

mapfile -t panels < <(find "$panel_dir" -maxdepth 1 -type f -name '*_rain_hour_*_BJT.png' -print | sort)
if [[ "${#panels[@]}" -ne 36 ]]; then
  echo "ERROR: expected 36 T13-T48 panels, found ${#panels[@]} for $run_prefix" >&2
  exit 1
fi

montage "${panels[@]}" -tile 6x6 -geometry '100%x100%+2+2' -background white "$overview"
for page in 1 2 3; do
  start=$(( (page - 1) * 12 ))
  detail="${detail_prefix}0${page}_4x3_grid.png"
  montage "${panels[@]:start:12}" -tile 4x3 -geometry '100%x100%+2+2' -background white "$detail"
  touch -r "$source_path" "$detail"
done
touch -r "$source_path" "$overview"
echo "Rendered $overview"
