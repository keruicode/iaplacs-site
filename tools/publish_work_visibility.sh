#!/usr/bin/env bash
# Independent, retryable VIS postprocessing. WRF inputs remain read-only.
set -Eeuo pipefail
if [[ "${IAPLACS_PUBLISH_VISIBILITY:-1}" != "1" ]]; then
  echo "Visibility publication disabled by operator"
  exit 0
fi
source "$(dirname "${BASH_SOURCE[0]}")/runtime_paths.sh"
ROOT="$(iaplacs_runtime_root "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
MODEL_ROOT="${WORK_VISIBILITY_MODEL_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK}"
OUTPUT_ROOT="${WORK_VISIBILITY_OUTPUT_ROOT:-$ROOT/worknx_ningxia_overview}"
PYTHON_BIN="${PYTHON_BIN:-/public/software/apps/conda/latest/bin/python3}"
run=""; ensure_public=0
while (( $# )); do
  case "$1" in
    --run) run="${2:-}"; shift 2 ;;
    --ensure-public) ensure_public=1; shift ;;
    *) echo "ERROR: unsupported visibility argument: $1" >&2; exit 64 ;;
  esac
done
[[ "$run" =~ ^[0-9]{8}_[0-9]{2}$ ]] || exit 64
[[ "$run" < "20261027_18" ]] && exit 0
wrf_dir="$MODEL_ROOT/${run/_/}/gfs/wrf"
source_file="$wrf_dir/wrfout_d01_${run:0:4}-${run:4:2}-${run:6:2}_${run:9:2}:00:00"
if [[ ! -f "$source_file" || ! -f "$wrf_dir/rsl.error.0000" ]] || \
   ! tail -n 200 "$wrf_dir/rsl.error.0000" | grep -q 'SUCCESS COMPLETE WRF'; then
  echo "Visibility $run: waiting for completed WRF output"
  exit 0
fi
output="$OUTPUT_ROOT/$run/visibility"
mkdir -p "$OUTPUT_ROOT"
exec 7>"$OUTPUT_ROOT/.visibility.lock"
flock -n 7 || { echo "Visibility publisher busy; retry next audit"; exit 75; }

arguments=(--input "$source_file" --output "$output" --if-needed
  --province-shp "${VISIBILITY_PROVINCE_SHP:-$ROOT/SHP/省界_region.shp}")
county="${VISIBILITY_COUNTY_SHP:-$ROOT/SHP/ningxia_city_county.shp}"
[[ -f "$county" ]] && arguments+=(--county-shp "$county")
status=0
"$PYTHON_BIN" "$IAPLACS_SCRIPT_DIR/render_work_visibility.py" "${arguments[@]}" || status=$?
if (( status == 3 )); then
  echo "Visibility $run: source has no VIS; existing weather products unchanged"
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
  --family worknx_summary --run-prefix "$run" --visibility-dir "$output"
printf '%s\n' "$digest" > "$receipt.tmp.$$"
mv "$receipt.tmp.$$" "$receipt"
echo "Visibility $run: published with raw-VIS QC"
