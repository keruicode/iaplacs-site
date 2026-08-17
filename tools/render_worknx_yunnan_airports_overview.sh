#!/usr/bin/env bash

# Render a Yunnan airport hourly precipitation overview from WORK_yn.
# Panels start at T13 after the first 12 spin-up hours and grow as WRF writes.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_YN_ROOT="${WORK_YN_ROOT:-${WORK_NX_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK_yn}}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$SCRIPT_DIR/worknx_yunnan_airports_overview}"
NCL_SCRIPT="${NCL_SCRIPT:-$SCRIPT_DIR/rain_worknx_yunnan_airport_hour_bjt.ncl}"
NATIONAL_NCL_SCRIPT="${NATIONAL_NCL_SCRIPT:-$SCRIPT_DIR/rain_worknx_national_hour_bjt.ncl}"
POINT_SCRIPT="${POINT_SCRIPT:-$SCRIPT_DIR/extract_yunnan_airport_precip.py}"
NCL_BIN="${NCL_BIN:-/public/software/apps/ncl_ncarg/ncl630/bin/ncl}"
NCL_ROOT="${NCL_ROOT:-/public/software/apps/ncl_ncarg/ncl630}"
NCDUMP_BIN="${NCDUMP_BIN:-/public/software/apps/conda/latest/bin/ncdump}"
PYTHON_BIN="${PYTHON_BIN:-}"
MIN_FILE_AGE_SECONDS="${MIN_FILE_AGE_SECONDS:-1200}"
MIN_WRFOUT_BYTES="${MIN_WRFOUT_BYTES:-8000000000}"
MIN_TIME_COUNT="${MIN_TIME_COUNT:-14}"
YUNNAN_PROVINCE_SHP_FILE="${YUNNAN_PROVINCE_SHP_FILE:-$SCRIPT_DIR/SHP/省界_region.shp}"
YUNNAN_CITY_SHP_FILE="${YUNNAN_CITY_SHP_FILE:-${YUNNAN_COUNTY_SHP_FILE:-$SCRIPT_DIR/SHP/yunnan_city.shp}}"

usage() {
  cat <<'EOF'
Usage: render_worknx_yunnan_airports_overview.sh [--latest | --recent COUNT]

Renders Yunnan panels from T13 through the latest available lead with airport
markers, plus a nationwide counterpart and airport point-precipitation totals.
EOF
}

if [[ -z "$PYTHON_BIN" ]]; then
  for candidate in /public/software/apps/conda/latest/bin/python3; do
    if [[ -x "$candidate" ]]; then
      PYTHON_BIN="$candidate"
      break
    fi
  done
fi
if [[ -z "$PYTHON_BIN" ]]; then
  PYTHON_BIN="$(command -v python3 || true)"
fi
if [[ -z "$PYTHON_BIN" || ! -x "$PYTHON_BIN" ]]; then
  echo "ERROR: Python 3 is required for airport precipitation extraction" >&2
  exit 127
fi
if ! "$PYTHON_BIN" -c 'import sys; raise SystemExit(0 if sys.version_info[0] >= 3 else 1)'; then
  echo "ERROR: Python 3 is required, got: $PYTHON_BIN" >&2
  exit 127
fi

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
if ! [[ "$MIN_TIME_COUNT" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: MIN_TIME_COUNT must be a positive integer" >&2
  exit 64
fi
if [[ ! -d "$WORK_YN_ROOT" ]]; then
  echo "ERROR: WORK_YN_ROOT not found: $WORK_YN_ROOT" >&2
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
if [[ ! -f "$POINT_SCRIPT" ]]; then
  echo "ERROR: point extraction script not found: $POINT_SCRIPT" >&2
  exit 1
fi
[[ -x "$NCL_BIN" ]] || { echo "ERROR: ncl is required: $NCL_BIN" >&2; exit 127; }
[[ -d "$NCL_ROOT/lib/ncarg" ]] || { echo "ERROR: NCARG_ROOT is invalid: $NCL_ROOT" >&2; exit 127; }
command -v montage >/dev/null || { echo "ERROR: ImageMagick montage is required" >&2; exit 127; }
command -v convert >/dev/null || { echo "ERROR: ImageMagick convert is required" >&2; exit 127; }
[[ -x "$NCDUMP_BIN" ]] || { echo "ERROR: ncdump is required: $NCDUMP_BIN" >&2; exit 127; }
export NCARG_ROOT="$NCL_ROOT"

if [[ -n "$YUNNAN_PROVINCE_SHP_FILE" && ! -f "$YUNNAN_PROVINCE_SHP_FILE" ]]; then
  echo "WARNING: Yunnan province SHP not found, province outline will be skipped: $YUNNAN_PROVINCE_SHP_FILE" >&2
fi
if [[ -n "$YUNNAN_CITY_SHP_FILE" && ! -f "$YUNNAN_CITY_SHP_FILE" ]]; then
  echo "WARNING: Yunnan city SHP not found, city outline will be skipped: $YUNNAN_CITY_SHP_FILE" >&2
fi

mkdir -p "$OUTPUT_ROOT"
now_epoch="$(date +%s)"
sources=()

wrf_time_count() {
  "$NCDUMP_BIN" -h "$1" 2>/dev/null | awk '/Time = UNLIMITED/ && !seen { gsub(/[^0-9]/, "", $0); print; seen=1 }'
}

wrf_completed_successfully() {
  local rsl_file
  rsl_file="$(dirname "$1")/rsl.error.0000"
  [[ -f "$rsl_file" ]] && tail -n 200 "$rsl_file" | grep -q 'SUCCESS COMPLETE WRF'
}

while IFS= read -r line; do
  source_path="$line"
  source_epoch="$(stat -c '%Y' "$source_path")"
  source_size="$(stat -c '%s' "$source_path")"
  if (( source_size < MIN_WRFOUT_BYTES )); then
    continue
  fi
  time_count="$(wrf_time_count "$source_path")"
  [[ "$time_count" =~ ^[0-9]+$ ]] && (( time_count >= MIN_TIME_COUNT )) || continue
  if ! wrf_completed_successfully "$source_path"; then
    (( now_epoch - source_epoch >= MIN_FILE_AGE_SECONDS )) || continue
  fi
  sources+=("$source_path")
  [[ "${#sources[@]}" -ge "$count" ]] && break
done < <(
  find "$WORK_YN_ROOT" -maxdepth 4 -type f \
    -name 'wrfout_d01_*' -printf '%p\n' \
    | sort -r
)

if [[ "${#sources[@]}" -eq 0 ]]; then
  echo "ERROR: no stable WORK_yn wrfout source found" >&2
  exit 1
fi

caption_panel() {
  local panel_path="$1" caption_dir="$2" add_time_caption="${3:-1}" panel_name panel_date caption_path
  panel_name="$(basename "$panel_path")"
  caption_path="$caption_dir/$panel_name"

  # Nationwide hourly panels already include their BJT interval in NCL.
  # Keep that single title and only add an external caption to regional panels.
  if [[ "$add_time_caption" != "1" ]]; then
    convert "$panel_path" -trim +repage "$caption_path"
    return
  fi

  if [[ ! "$panel_name" =~ _rain_hour_([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})-([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})_BJT\.png$ ]]; then
    echo "ERROR: cannot parse panel date from $panel_name" >&2
    return 1
  fi
  panel_date="${BASH_REMATCH[2]}-${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:00-${BASH_REMATCH[8]}:00"

  convert "$panel_path" \
    -trim +repage \
    -gravity North \
    -background white \
    -splice 0x92 \
    -fill black \
    -font Times-Bold \
    -stroke black \
    -strokewidth 1 \
    -pointsize 92 \
    -annotate +0+24 "$panel_date" \
    "$caption_path"
}

add_overview_header() {
  local overview_path="$1" init_label="$2"
  convert "$overview_path" \
    -gravity North \
    -background white \
    -splice 0x152 \
    -fill black \
    -font Times-Bold \
    -stroke black \
    -strokewidth 1 \
    -pointsize 128 \
    -annotate +0+20 "Forecast Initialization: $init_label" \
    "$overview_path"
}

format_bjt_interval() {
  local start="$1" end="$2"
  printf '%s-%s-%s %s:00 - %s-%s-%s %s:00 BJT' \
    "${start:0:4}" "${start:4:2}" "${start:6:2}" "${start:8:2}" \
    "${end:0:4}" "${end:4:2}" "${end:6:2}" "${end:8:2}"
}

caption_accumulation() {
  local source_path="$1" output_path="$2" hours="$3" start="$4" end="$5" interval
  interval="$(format_bjt_interval "$start" "$end")"

  # Trim the NCL square canvas before adding the complete BJT interval label.
  convert "$source_path" \
    -trim +repage \
    -bordercolor white \
    -border 20 \
    -gravity North \
    -background white \
    -splice 0x112 \
    -fill black \
    -font Times-Bold \
    -stroke black \
    -strokewidth 1 \
    -pointsize 34 \
    -annotate +0+10 "${hours} h Accumulated Precipitation\n${interval}" \
    "$output_path"
}

write_manifest() {
  local manifest_path="$1" run_prefix="$2" source_path="$3" overview="$4" totals_json="$5" last_lead="$6"
  "$PYTHON_BIN" - "$manifest_path" "$run_prefix" "$source_path" "$overview" "$totals_json" "$last_lead" <<'PY'
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

manifest_path = Path(sys.argv[1])
run_prefix = sys.argv[2]
source_path = Path(sys.argv[3])
overview = Path(sys.argv[4])
totals_path = Path(sys.argv[5])
last_lead = int(sys.argv[6])
bjt = timezone(timedelta(hours=8))
run_dt_utc = datetime.strptime(run_prefix, "%Y%m%d_%H").replace(tzinfo=timezone.utc)
run_dt_bjt = run_dt_utc.astimezone(bjt)
valid_dt_bjt = (run_dt_utc + timedelta(hours=last_lead)).astimezone(bjt)
generated_at = datetime.fromtimestamp(source_path.stat().st_mtime, tz=bjt)
with totals_path.open(encoding="utf-8") as handle:
    totals = json.load(handle)

payload = {
    "run_prefix": run_prefix,
    "source_image": str(source_path),
    "file": f"./data/current/maps/airport_yunnan_{run_prefix}/{overview.name}",
    "run_time": run_dt_bjt.isoformat(),
    "valid_time": valid_dt_bjt.isoformat(),
    "generated_at": generated_at.replace(microsecond=0).isoformat(),
    "bytes": overview.stat().st_size,
    "airport_precip_totals": totals.get("airports", []),
}
manifest_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

render_source() {
  local source_path="$1" base run_date run_hour run_prefix wrf_dir run_dir panel_dir caption_dir overview totals_json manifest_json time_count last_lead panel_count overview_rows overview_grid national_panel_dir national_caption_dir national_overview frozen_panel_dir frozen_caption_dir frozen_overview init_bjt
  base="$(basename "$source_path")"
  if [[ "$base" =~ wrfout_d01_([0-9]{4})-([0-9]{2})-([0-9]{2})_([0-9]{2}):[0-9]{2}:[0-9]{2} ]]; then
    run_date="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]}"
    run_hour="${BASH_REMATCH[4]}"
    run_prefix="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}_${run_hour}"
  elif [[ "$base" =~ InitUTC_([0-9]{4})-([0-9]{2})-([0-9]{2})_([0-9]{2})_[0-9]{2} ]]; then
    run_date="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]}"
    run_hour="${BASH_REMATCH[4]}"
    run_prefix="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}_${run_hour}"
  else
    echo "ERROR: cannot parse run time from $base" >&2
    return 1
  fi
  init_bjt="$(TZ=Asia/Shanghai date -d "${run_date} ${run_hour}:00 UTC" '+%Y-%m-%d %H:%M BJT')"
  wrf_dir="$(dirname "$source_path")"
  run_dir="$OUTPUT_ROOT/$run_prefix"
  panel_dir="$run_dir/hourly_t13_t48"
  caption_dir="$run_dir/captioned_t13_t48"
  national_panel_dir="$run_dir/national_hourly_t13_t48"
  national_caption_dir="$run_dir/national_captioned_t13_t48"
  frozen_panel_dir="$run_dir/frozen_hourly_t13_t48"
  frozen_caption_dir="$run_dir/frozen_captioned_t13_t48"
  totals_json="$run_dir/airport_precip_totals.json"
  manifest_json="$run_dir/manifest_fragment.json"

  if ! compgen -G "$wrf_dir/wrfout_d01_*" >/dev/null; then
    echo "ERROR: wrfout_d01 files are unavailable beside $source_path" >&2
    return 1
  fi
  time_count="$(wrf_time_count "$source_path")"
  [[ "$time_count" =~ ^[0-9]+$ ]] && (( time_count >= MIN_TIME_COUNT )) || {
    echo "ERROR: T13 is not available in $source_path" >&2
    return 1
  }
  last_lead=$((time_count - 1))

  mkdir -p "$panel_dir" "$caption_dir" "$national_panel_dir" "$national_caption_dir" \
    "$frozen_panel_dir" "$frozen_caption_dir"
  rm -f "$panel_dir"/*.png "$caption_dir"/*.png \
    "$national_panel_dir"/*.png "$national_caption_dir"/*.png \
    "$frozen_panel_dir"/*.png "$frozen_caption_dir"/*.png
  rm -f "$run_dir"/Precip_hourly_WRF_YunnanAirports_T13_T*_InitUTC_"${run_date}"_"${run_hour}"_00_combined_overview_*_grid.* \
    "$run_dir"/Precip_hourly_WRF_YunnanAirportsFrozen_T13_T*_InitUTC_"${run_date}"_"${run_hour}"_00_combined_overview_*_grid.* \
    "$run_dir"/Precip_hourly_WRF_AllRain_T13_T*_InitUTC_"${run_date}"_"${run_hour}"_00_combined_overview_*_grid.*
  echo "Rendering Yunnan airport T13-T${last_lead} panels for $run_prefix from $wrf_dir"
  WORK_YN_WRF_DIR="$wrf_dir" \
    WORK_YN_YUNNAN_AIRPORT_PNG_DIR="$panel_dir" \
    YUNNAN_PROVINCE_SHP_FILE="$YUNNAN_PROVINCE_SHP_FILE" \
    YUNNAN_CITY_SHP_FILE="$YUNNAN_CITY_SHP_FILE" \
    RAIN_COMPONENT_MODE=total \
    RAIN_OUTPUT_AREA=yunnan_airport \
    "$NCL_BIN" "$NCL_SCRIPT"

  local panels=()
  mapfile -t panels < <(find "$panel_dir" -maxdepth 1 -type f -name '*_rain_hour_*_BJT.png' -print | sort)
  panel_count="${#panels[@]}"
  if (( panel_count != last_lead - 12 )); then
    echo "ERROR: expected $((last_lead - 12)) panels, found ${panel_count} for $run_prefix" >&2
    return 1
  fi
  if (( panel_count == 12 )); then
    overview_grid="3x4"
  else
    overview_rows=$(((panel_count + 5) / 6))
    overview_grid="6x${overview_rows}"
  fi
  overview="$run_dir/Precip_hourly_WRF_YunnanAirports_T13_T${last_lead}_InitUTC_${run_date}_${run_hour}_00_combined_overview_${overview_grid}_grid.png"
  national_overview="$run_dir/Precip_hourly_WRF_AllRain_T13_T${last_lead}_InitUTC_${run_date}_${run_hour}_00_combined_overview_${overview_grid}_grid.png"

  local captioned_panels=()
  for panel in "${panels[@]}"; do
    caption_panel "$panel" "$caption_dir"
    captioned_panels+=("$caption_dir/$(basename "$panel")")
  done

  montage "${captioned_panels[@]}" -tile "$overview_grid" -geometry '100%x100%+2+2' -background white "$overview"
  add_overview_header "$overview" "$init_bjt"
  touch -r "$source_path" "$overview"

  echo "Rendering Yunnan airport hail-warning T13-T${last_lead} panels for $run_prefix"
  WORK_NX_WRF_DIR="$wrf_dir" \
    WORK_NX_NATIONAL_PNG_DIR="$frozen_panel_dir" \
    WORK_NX_NATIONAL_PROVINCE_SHP_FILE="$YUNNAN_PROVINCE_SHP_FILE" \
    WORK_NX_NATIONAL_REGION_MODE=yunnan_national \
    RAIN_COMPONENT_MODE=frozen \
    RAIN_OUTPUT_AREA=yunnan_hail_warning \
    "$NCL_BIN" "$NATIONAL_NCL_SCRIPT"
  local frozen_panels=() frozen_captioned_panels=()
  mapfile -t frozen_panels < <(find "$frozen_panel_dir" -maxdepth 1 -type f -name '*_yunnan_hail_warning_rain_hour_*_BJT.png' -print | sort)
  if (( ${#frozen_panels[@]} != panel_count )); then
    echo "ERROR: expected ${panel_count} Yunnan hail-warning panels, found ${#frozen_panels[@]} for $run_prefix" >&2
    return 1
  fi
  frozen_overview="$run_dir/Precip_hourly_WRF_YunnanAirportsFrozen_T13_T${last_lead}_InitUTC_${run_date}_${run_hour}_00_combined_overview_${overview_grid}_grid.png"
  for panel in "${frozen_panels[@]}"; do
    caption_panel "$panel" "$frozen_caption_dir" 0
    frozen_captioned_panels+=("$frozen_caption_dir/$(basename "$panel")")
  done
  montage "${frozen_captioned_panels[@]}" -tile "$overview_grid" -geometry '100%x100%+2+2' -background white "$frozen_overview"
  add_overview_header "$frozen_overview" "$init_bjt"
  touch -r "$source_path" "$frozen_overview"

  WORK_NX_WRF_DIR="$wrf_dir" \
    WORK_NX_NATIONAL_PNG_DIR="$national_panel_dir" \
    WORK_NX_NATIONAL_PROVINCE_SHP_FILE="$YUNNAN_PROVINCE_SHP_FILE" \
    WORK_NX_NATIONAL_REGION_MODE=yunnan_national \
    "$NCL_BIN" "$NATIONAL_NCL_SCRIPT"
  local national_panels=() national_captioned_panels=()
  mapfile -t national_panels < <(find "$national_panel_dir" -maxdepth 1 -type f -name '*_national_rain_hour_*_BJT.png' -print | sort)
  if (( ${#national_panels[@]} != panel_count )); then
    echo "ERROR: expected ${panel_count} nationwide panels, found ${#national_panels[@]} for $run_prefix" >&2
    return 1
  fi
  for panel in "${national_panels[@]}"; do
    caption_panel "$panel" "$national_caption_dir" 0
    national_captioned_panels+=("$national_caption_dir/$(basename "$panel")")
  done
  montage "${national_captioned_panels[@]}" -tile "$overview_grid" -geometry '100%x100%+2+2' -background white "$national_overview"
  add_overview_header "$national_overview" "$init_bjt"
  touch -r "$source_path" "$national_overview"
  # Keep only BJT-aligned accumulation windows for this forecast run.
  rm -f "$run_dir"/Precip_accum_*h_WRF_YunnanAirports_T13_T*_InitUTC_"${run_date}"_"${run_hour}"_00*combined_overview_1x1_grid.*
  rm -f "$panel_dir"/*_national_accum_*.png
  for accum_hours in 12 24; do
    local accum_source accum_overview accum_name accum_start accum_end
    WORK_NX_WRF_DIR="$wrf_dir" \
      WORK_NX_NATIONAL_PNG_DIR="$panel_dir" \
      WORK_NX_NATIONAL_PROVINCE_SHP_FILE="$YUNNAN_PROVINCE_SHP_FILE" \
      WORK_NX_NATIONAL_REGION_MODE=yunnan_national \
      RAIN_ACCUM_HOURS="$accum_hours" \
      "$NCL_BIN" "$NATIONAL_NCL_SCRIPT"
    while IFS= read -r accum_source; do
      [[ -n "$accum_source" ]] || continue
      accum_name="$(basename "$accum_source")"
      accum_name="${accum_name#*_national_accum_${accum_hours}h_}"
      accum_name="${accum_name%_BJT.png}"
      if [[ ! "$accum_name" =~ ^([0-9]{10})-([0-9]{10})$ ]]; then
        echo "ERROR: cannot parse BJT accumulation interval from $accum_source" >&2
        return 1
      fi
      accum_start="${BASH_REMATCH[1]}"
      accum_end="${BASH_REMATCH[2]}"
      accum_overview="$run_dir/Precip_accum_${accum_hours}h_WRF_YunnanAirports_T13_T${last_lead}_InitUTC_${run_date}_${run_hour}_00_${accum_name}_combined_overview_1x1_grid.png"
      caption_accumulation "$accum_source" "$accum_overview" "$accum_hours" "$accum_start" "$accum_end"
      touch -r "$source_path" "$accum_overview"
    done < <(find "$panel_dir" -maxdepth 1 -type f -name "*_national_accum_$(printf '%02d' "$accum_hours")h_*_BJT.png" | sort)
  done
  "$PYTHON_BIN" "$POINT_SCRIPT" --wrf-dir "$wrf_dir" --output "$totals_json" --start 13 --end "$last_lead"
  write_manifest "$manifest_json" "$run_prefix" "$source_path" "$overview" "$totals_json" "$last_lead"
  echo "Rendered $overview"
}

for source_path in "${sources[@]}"; do
  render_source "$source_path"
done
