#!/usr/bin/env bash

# Render a Yunnan airport hourly precipitation overview from WORK_yn.
# Thirty-six hourly panels remain after the first 12 spin-up hours, so the
# product is intentionally one 6x6 image with airport markers.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_YN_ROOT="${WORK_YN_ROOT:-${WORK_NX_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK_yn}}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$SCRIPT_DIR/worknx_yunnan_airports_overview}"
NCL_SCRIPT="${NCL_SCRIPT:-$SCRIPT_DIR/rain_worknx_yunnan_airport_hour_bjt.ncl}"
POINT_SCRIPT="${POINT_SCRIPT:-$SCRIPT_DIR/extract_yunnan_airport_precip.py}"
NCL_BIN="${NCL_BIN:-/public/software/apps/ncl_ncarg/ncl630/bin/ncl}"
NCL_ROOT="${NCL_ROOT:-/public/software/apps/ncl_ncarg/ncl630}"
PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || command -v python)}"
MIN_FILE_AGE_SECONDS="${MIN_FILE_AGE_SECONDS:-1200}"
MIN_WRFOUT_BYTES="${MIN_WRFOUT_BYTES:-20000000000}"
YUNNAN_PROVINCE_SHP_FILE="${YUNNAN_PROVINCE_SHP_FILE:-$SCRIPT_DIR/SHP/省界_region.shp}"

usage() {
  cat <<'EOF'
Usage: render_worknx_yunnan_airports_overview.sh [--latest | --recent COUNT]

Reads stable WORK_yn wrfout files, renders the 36-hour Yunnan panels with
airport markers, and writes one *_combined_overview_6x6_grid.png per run plus
airport point-precipitation totals.
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
if [[ ! -d "$WORK_YN_ROOT" ]]; then
  echo "ERROR: WORK_YN_ROOT not found: $WORK_YN_ROOT" >&2
  exit 1
fi
if [[ ! -f "$NCL_SCRIPT" ]]; then
  echo "ERROR: NCL script not found: $NCL_SCRIPT" >&2
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
export NCARG_ROOT="$NCL_ROOT"

if [[ -n "$YUNNAN_PROVINCE_SHP_FILE" && ! -f "$YUNNAN_PROVINCE_SHP_FILE" ]]; then
  echo "WARNING: Yunnan province SHP not found, province outline will be skipped: $YUNNAN_PROVINCE_SHP_FILE" >&2
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
  find "$WORK_YN_ROOT" -maxdepth 4 -type f \
    -name 'wrfout_d01_*' -printf '%T@ %s %p\n' \
    | sort -nr
)

if [[ "${#sources[@]}" -eq 0 ]]; then
  echo "ERROR: no stable WORK_yn wrfout source found" >&2
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

write_manifest() {
  local manifest_path="$1" run_prefix="$2" source_path="$3" overview="$4" totals_json="$5"
  "$PYTHON_BIN" - "$manifest_path" "$run_prefix" "$source_path" "$overview" "$totals_json" <<'PY'
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

manifest_path = Path(sys.argv[1])
run_prefix = sys.argv[2]
source_path = Path(sys.argv[3])
overview = Path(sys.argv[4])
totals_path = Path(sys.argv[5])
bjt = timezone(timedelta(hours=8))
run_dt_utc = datetime.strptime(run_prefix, "%Y%m%d_%H").replace(tzinfo=timezone.utc)
run_dt_bjt = run_dt_utc.astimezone(bjt)
valid_dt_bjt = (run_dt_utc + timedelta(hours=48)).astimezone(bjt)
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
  local source_path="$1" base run_date run_hour run_prefix wrf_dir run_dir panel_dir caption_dir overview totals_json manifest_json
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
  wrf_dir="$(dirname "$source_path")"
  run_dir="$OUTPUT_ROOT/$run_prefix"
  panel_dir="$run_dir/hourly_t13_t48"
  caption_dir="$run_dir/captioned_t13_t48"
  overview="$run_dir/Precip_hourly_WRF_YunnanAirports_T13_T48_InitUTC_${run_date}_${run_hour}_00_combined_overview_6x6_grid.png"
  totals_json="$run_dir/airport_precip_totals.json"
  manifest_json="$run_dir/manifest_fragment.json"

  if ! compgen -G "$wrf_dir/wrfout_d01_*" >/dev/null; then
    echo "ERROR: wrfout_d01 files are unavailable beside $source_path" >&2
    return 1
  fi

  mkdir -p "$panel_dir" "$caption_dir"
  echo "Rendering Yunnan airport 36-hour panels for $run_prefix from $wrf_dir"
  WORK_YN_WRF_DIR="$wrf_dir" \
    WORK_YN_YUNNAN_AIRPORT_PNG_DIR="$panel_dir" \
    YUNNAN_PROVINCE_SHP_FILE="$YUNNAN_PROVINCE_SHP_FILE" \
    "$NCL_BIN" "$NCL_SCRIPT"

  local panels=()
  mapfile -t panels < <(find "$panel_dir" -maxdepth 1 -type f -name '*_rain_hour_*_BJT.png' -print | sort)
  if [[ "${#panels[@]}" -ne 36 ]]; then
    echo "ERROR: expected 36 panels, found ${#panels[@]} for $run_prefix" >&2
    return 1
  fi

  local captioned_panels=()
  for panel in "${panels[@]}"; do
    caption_panel "$panel" "$caption_dir"
    captioned_panels+=("$caption_dir/$(basename "$panel")")
  done

  montage "${captioned_panels[@]}" -tile 6x6 -geometry '100%x100%+2+2' -background white "$overview"
  touch -r "$source_path" "$overview"
  "$PYTHON_BIN" "$POINT_SCRIPT" --wrf-dir "$wrf_dir" --output "$totals_json" --start 13 --end 48
  write_manifest "$manifest_json" "$run_prefix" "$source_path" "$overview" "$totals_json"
  echo "Rendered $overview"
}

for source_path in "${sources[@]}"; do
  render_source "$source_path"
done
