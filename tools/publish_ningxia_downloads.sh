#!/usr/bin/env bash
# Extraction is compute-only; OSS transmission stays on the publication node.
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/runtime_paths.sh"
source "$IAPLACS_SCRIPT_DIR/plot_scheduler.sh"
iaplacs_plot_entry "$IAPLACS_SCRIPT_DIR/$(basename "$0")" "$@"
root="$(iaplacs_runtime_root "$IAPLACS_SCRIPT_DIR")"
model="${NINGXIA_DOWNLOAD_MODEL_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK}"
output="${NINGXIA_DOWNLOAD_OUTPUT:-$root/ningxia_downloads}"
python="${PYTHON_BIN:-/public/software/apps/conda/latest/bin/python3}"
mode="${1:---recent}"
case "$mode" in
  --recent)
    count="${2:-5}"
    [[ "$count" =~ ^[1-9]$ ]] || exit 64
    mapfile -t runs < <(find "$model" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | grep -E '^[0-9]{10}$' | sort -r | head -n "$count") ;;
  --run|--render-only)
    run="${2:-}"
    run="${run/_/}"
    [[ "$run" =~ ^[0-9]{10}$ ]] || exit 64
    runs=("$run") ;;
  *) exit 64 ;;
esac
mkdir -p "$output"
exec 6>"$output/.export.lock"
flock -n 6 || exit 75
failed=0
for run in "${runs[@]}"; do
  wrf="$model/$run/gfs/wrf"
  [[ -f "$wrf/rsl.error.0000" ]] || continue
  tail -n 200 "$wrf/rsl.error.0000" | grep -q 'SUCCESS COMPLETE WRF' || continue
  stamp="${run:0:4}-${run:4:2}-${run:6:2}_${run:8:2}:00:00"
  source="$wrf/wrfout_d01_$stamp"
  [[ ! -f "$wrf/wrfout_d02_$stamp" ]] || source="$wrf/wrfout_d02_$stamp"
  [[ -f "$source" ]] || continue
  prefix="${run:0:8}_${run:8:2}"
  destination="$output/$prefix"
  if ! "$python" "$IAPLACS_SCRIPT_DIR/export_ningxia_download.py" --input "$source" --output "$destination"; then
    failed=1
    continue
  fi
  [[ "$mode" != --render-only ]] || continue
  if ! bash "$IAPLACS_SCRIPT_DIR/upload_ningxia_download.sh" "$prefix" "$destination"; then
    failed=1
  fi
done
exit "$failed"
