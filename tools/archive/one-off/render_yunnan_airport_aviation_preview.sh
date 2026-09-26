#!/usr/bin/env bash

# One-off aviation preview.  This script intentionally never calls a publisher.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_UTC="${1:-20260818_00}"
RUN_COMPACT="${RUN_UTC/_/}"
WORK_ROOT="${WORK_YN_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK_yn}"
RUNTIME_ROOT="${RUNTIME_ROOT:-/data1/elpt_2022_00083/kerui/Website}"
PYTHON_BIN="${PYTHON_BIN:-/public/software/apps/conda/latest/bin/python3}"
INPUT="$WORK_ROOT/$RUN_COMPACT/gfs/wrf/wrfout_d01_${RUN_UTC:0:4}-${RUN_UTC:4:2}-${RUN_UTC:6:2}_${RUN_UTC:9:2}:00:00"
OUTPUT="$RUNTIME_ROOT/worknx_yunnan_airports_overview/$RUN_UTC/aviation_preview"

[[ -x "$PYTHON_BIN" ]] || { echo "Python not executable: $PYTHON_BIN" >&2; exit 127; }
[[ -f "$INPUT" ]] || { echo "WRF output not found: $INPUT" >&2; exit 1; }
if ! tail -n 200 "$(dirname "$INPUT")/rsl.error.0000" | grep -q 'SUCCESS COMPLETE WRF'; then
  echo "WRF run is not complete: $INPUT" >&2
  exit 1
fi

rm -rf "$OUTPUT"
mkdir -p "$OUTPUT/.mplconfig"
export MPLCONFIGDIR="$OUTPUT/.mplconfig"
"$PYTHON_BIN" "$SCRIPT_DIR/render_yunnan_airport_aviation_preview.py" \
  --input "$INPUT" \
  --output "$OUTPUT" \
  --province-shp "$RUNTIME_ROOT/SHP/省界_region.shp" \
  --city-shp "$RUNTIME_ROOT/SHP/yunnan_city.shp" \
  --start 13 --count 12

echo "Preview only; no OSS, GitHub, catalog, or cron action was performed."
