#!/usr/bin/env bash
# Completed-run native DBZ composite; independent lock and retryable OSS receipt.
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/runtime_paths.sh"
ROOT="$(iaplacs_runtime_root "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
PYTHON_BIN="${PYTHON_BIN:-/public/software/apps/conda/latest/bin/python3}"
run=""; ensure_public=0; profile=yunnan
while (( $# )); do
  case "$1" in
    --run) run="${2:-}"; shift 2 ;;
    --profile) profile="${2:-}"; shift 2 ;;
    --ensure-public) ensure_public=1; shift ;;
    *) exit 64 ;;
  esac
done
case "$profile" in
  yunnan) model=WORK_yn; folder=worknx_yunnan_airports_overview; family=airport_yunnan; city="$ROOT/SHP/yunnan_city.shp" ;;
  ningxia) model=WORK; folder=worknx_ningxia_overview; family=worknx_summary; city="" ;;
  xinjiang) model=WORK_xj; folder=workxj_xinjiang_overview; family=workxj_summary; city="" ;;
  *) echo "Unsupported radar profile: $profile" >&2; exit 64 ;;
esac
MODEL_ROOT="${RADAR_MODEL_ROOT:-/data1/elpt_2022_00083/zhoubj/$model}"
OUTPUT_ROOT="${RADAR_OUTPUT_ROOT:-$ROOT/$folder}"
[[ "$run" =~ ^[0-9]{8}_[0-9]{2}$ ]] || exit 64
[[ "$run" < "20261028_12" ]] && exit 0
wrf_dir="$MODEL_ROOT/${run/_/}/gfs/wrf"
if [[ ! -f "$wrf_dir/rsl.error.0000" ]] || ! tail -n 200 "$wrf_dir/rsl.error.0000" | grep -q 'SUCCESS COMPLETE WRF'; then
  echo "Radar $run: waiting for completed WRF output"
  exit 0
fi
mkdir -p "$OUTPUT_ROOT"
exec 7>"$OUTPUT_ROOT/.radar.lock"
flock -n 7 || { echo "Radar publisher busy; retry next audit"; exit 75; }
source_file="$wrf_dir/wrfout_d01_${run:0:4}-${run:4:2}-${run:6:2}_${run:9:2}:00:00"
# Prefer a complete nested source; never substitute a different initialization.
source_file="$("$PYTHON_BIN" - "$source_file" <<'PY'
import sys
from pathlib import Path
from netCDF4 import Dataset
p = Path(sys.argv[1])
for f in (p.with_name(p.name.replace('d01', 'd02', 1)), p):
    if not f.exists():
        continue
    with Dataset(f) as d:
        if len(d.dimensions['Time']) >= 14 and 'DBZ' in d.variables:
            print(f)
            break
else:
    raise SystemExit('No complete radar source with native DBZ')
PY
)"
domain=d01
[[ "$source_file" == */wrfout_d02_* ]] && domain=d02
output="$OUTPUT_ROOT/$run/radar"
map_args=(--province-shp "$ROOT/SHP/省界_region.shp")
[[ -z "$city" ]] || map_args+=(--city-shp "$city")
"$PYTHON_BIN" "$IAPLACS_SCRIPT_DIR/render_yunnan_radar.py" \
  --input "$source_file" --output "$output" --domain "$domain" --profile "$profile" --if-needed --dual-domain \
  "${map_args[@]}"
digest="$(sha256sum "$output/production_manifest.json" | awk '{print $1}')"
receipt="$output/.published-sha256"
if [[ -f "$receipt" && "$(<"$receipt")" == "$digest" ]]; then
  if (( ! ensure_public || $(date +%s) - $(stat -c %Y "$receipt") < 600 )); then
    echo "Radar $run: already published"
    exit 0
  fi
fi
"$IAPLACS_SCRIPT_DIR/publish_airport_aviation_to_oss.sh" \
  --family "$family" --run-prefix "$run" --radar-dir "$output"
printf '%s\n' "$digest" > "$receipt.tmp.$$"
mv "$receipt.tmp.$$" "$receipt"
echo "Radar $run: published quality-controlled native DBZ composite"
