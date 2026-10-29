#!/usr/bin/env bash
# Completed-run NCL radar diagnostics; independent lock and retryable OSS receipt.
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/runtime_paths.sh"
ROOT="$(iaplacs_runtime_root "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
MODEL_ROOT="${RADAR_MODEL_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK_yn}"
OUTPUT_ROOT="${RADAR_OUTPUT_ROOT:-$ROOT/worknx_yunnan_airports_overview}"
PYTHON_BIN="${PYTHON_BIN:-/public/software/apps/conda/latest/bin/python3}"
run=""; ensure_public=0
while (( $# )); do
  case "$1" in
    --run) run="${2:-}"; shift 2 ;;
    --ensure-public) ensure_public=1; shift ;;
    *) exit 64 ;;
  esac
done
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
        if len(d.dimensions['Time']) >= 14 and all(n in d.variables for n in ('P','PB','T','QVAPOR','QRAIN','QSNOW','QGRAUP')):
            print(f)
            break
else:
    raise SystemExit('No complete radar source with required mass fields')
PY
)"
domain=d01
[[ "$source_file" == */wrfout_d02_* ]] && domain=d02
output="$OUTPUT_ROOT/$run/radar"
"$PYTHON_BIN" "$IAPLACS_SCRIPT_DIR/render_yunnan_radar_ncl.py" \
  --input "$source_file" --output "$output" --domain "$domain" --if-needed \
  --ncl "${NCL_BIN:-/public/software/apps/ncl_ncarg/ncl630/bin/ncl}" \
  --province-shp "$ROOT/SHP/省界_region.shp" --city-shp "$ROOT/SHP/yunnan_city.shp"
digest="$(sha256sum "$output/production_manifest.json" | awk '{print $1}')"
receipt="$output/.published-sha256"
if [[ -f "$receipt" && "$(<"$receipt")" == "$digest" ]]; then
  if (( ! ensure_public || $(date +%s) - $(stat -c %Y "$receipt") < 600 )); then
    echo "Radar $run: already published"
    exit 0
  fi
fi
"$IAPLACS_SCRIPT_DIR/publish_airport_aviation_to_oss.sh" \
  --family airport_yunnan --run-prefix "$run" --radar-dir "$output"
printf '%s\n' "$digest" > "$receipt.tmp.$$"
mv "$receipt.tmp.$$" "$receipt"
echo "Radar $run: published NCL composite"
