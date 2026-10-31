#!/usr/bin/env bash
# Independent, retryable VIS postprocessing. WRF inputs remain read-only.
set -Eeuo pipefail
if [[ "${IAPLACS_PUBLISH_VISIBILITY:-1}" != "1" ]]; then
  echo "Visibility publication disabled by operator"
  exit 0
fi
source "$(dirname "${BASH_SOURCE[0]}")/runtime_paths.sh"
ROOT="$(iaplacs_runtime_root "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
PYTHON_BIN="${PYTHON_BIN:-/public/software/apps/conda/latest/bin/python3}"
run=""; ensure_public=0; profile=ningxia
while (( $# )); do
  case "$1" in
    --run) run="${2:-}"; shift 2 ;;
    --profile) profile="${2:-}"; shift 2 ;;
    --ensure-public) ensure_public=1; shift ;;
    *) echo "ERROR: unsupported visibility argument: $1" >&2; exit 64 ;;
  esac
done
[[ "$run" =~ ^[0-9]{8}_[0-9]{2}$ ]] || exit 64
case "$profile" in
  ningxia) model=WORK; products=worknx_ningxia_overview; family=worknx_summary; variable=VIS_MIN; first_run=20261030_06; county_name=ningxia_city_county ;;
  yunnan) model=WORK_yn; products=worknx_yunnan_airports_overview; family=airport_yunnan; variable=auto; first_run=20261030_00; county_name=yunnan_city ;;
  xinjiang) model=WORK_xj; products=workxj_xinjiang_overview; family=workxj_summary; variable=auto; first_run=20261030_00; county_name=xinjiang_city ;;
  *) echo "ERROR: unsupported visibility profile: $profile" >&2; exit 64 ;;
esac
MODEL_ROOT="${WORK_VISIBILITY_MODEL_ROOT:-/data1/elpt_2022_00083/zhoubj/$model}"
OUTPUT_ROOT="${WORK_VISIBILITY_OUTPUT_ROOT:-$ROOT/$products}"
# Preserve previously published VIS history; migrate latest and future runs.
[[ "$run" < "$first_run" ]] && exit 0
wrf_dir="$MODEL_ROOT/${run/_/}/gfs/wrf"
source_file="$wrf_dir/wrfout_d01_${run:0:4}-${run:4:2}-${run:6:2}_${run:9:2}:00:00"
if [[ ! -f "$wrf_dir/rsl.error.0000" ]] || \
   ! tail -n 200 "$wrf_dir/rsl.error.0000" | grep -q 'SUCCESS COMPLETE WRF'; then
  echo "Visibility $run: waiting for completed WRF output"
  exit 0
fi
status=0
selection="$(PYTHONPATH="$IAPLACS_SCRIPT_DIR${PYTHONPATH:+:$PYTHONPATH}" "$PYTHON_BIN" - "$source_file" "$profile" <<'PY'
import sys
from pathlib import Path
from visibility_source import select_source
selected = select_source(Path(sys.argv[1]), sys.argv[2])
if selected is None:
    raise SystemExit(3)
print(str(selected[0]) + "|" + selected[1])
PY
)" || status=$?
if (( status == 3 )); then
  echo "Visibility $profile $run: no supported visibility field with post-spin-up times; skip"
  exit 0
fi
(( status == 0 )) || exit "$status"
IFS='|' read -r source_file source_kind <<< "$selection"
domain=d01
[[ "$source_file" == */wrfout_d02_* ]] && domain=d02
output="$OUTPUT_ROOT/$run/visibility"
mkdir -p "$OUTPUT_ROOT"
exec 7>"$OUTPUT_ROOT/.visibility.lock"
flock -n 7 || { echo "Visibility publisher busy; retry next audit"; exit 75; }

arguments=(--input "$source_file" --output "$output" --if-needed
  --variable "$variable" --profile "$profile" --domain "$domain"
  --province-shp "${VISIBILITY_PROVINCE_SHP:-$ROOT/SHP/省界_region.shp}")
county="${VISIBILITY_COUNTY_SHP:-$ROOT/SHP/$county_name.shp}"
[[ -f "$county" ]] && arguments+=(--county-shp "$county")
status=0
renderer=render_work_visibility.py
if [[ "$source_kind" == diagnostic ]]; then
  renderer=render_cloud_visibility_preview.py
  arguments+=(--production)
fi
"$PYTHON_BIN" "$IAPLACS_SCRIPT_DIR/$renderer" "${arguments[@]}" || status=$?
if (( status == 3 )); then
  echo "Visibility $profile $run: source lacks requested field ($variable); existing products unchanged"
  exit 0
fi
(( status == 0 )) || exit "$status"
manifest="$output/production_manifest.json"
digest="$(sha256sum "$manifest" | awk '{print $1}')"
receipt="$output/.published-sha256"
if [[ -f "$receipt" && "$(<"$receipt")" == "$digest" ]]; then
  if (( ! ensure_public || $(date +%s) - $(stat -c %Y "$receipt") < 600 )); then
    echo "Visibility $run: already published; no render or upload needed"
    exit 0
  fi
fi
"$IAPLACS_SCRIPT_DIR/publish_airport_aviation_to_oss.sh" \
  --family "$family" --run-prefix "$run" --visibility-dir "$output"
printf '%s\n' "$digest" > "$receipt.tmp.$$"
mv "$receipt.tmp.$$" "$receipt"
echo "Visibility $profile $run: published first-layer visibility ($variable) with display-only QC"
