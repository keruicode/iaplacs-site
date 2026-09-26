#!/usr/bin/env bash

# Preserve the legacy runtime root when launched from the organized directory.
if [[ -L "$(dirname "${BASH_SOURCE[0]}")/.runtime-root" ]]; then
  exec bash "$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.runtime-root" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@"
fi

set -Eeuo pipefail

WEBSITE="${WEBSITE:-/data1/elpt_2022_00083/kerui/Website}"
WRF_DIR="${WRF_DIR:-/data1/elpt_2022_00083/zhoubj/WORK/2026073000/gfs/wrf}"
PNG_DIR="${PNG_DIR:-$WEBSITE/wrf_hourly_png}"
RUN_PREFIX="${RUN_PREFIX:-20260730_08}"
NCL_BIN="${NCL_BIN:-/public/software/apps/ncl_ncarg/ncl630/bin/ncl}"

export NCARG_ROOT="${NCARG_ROOT:-/public/software/apps/ncl_ncarg/ncl630}"

for accumulation_hours in 12 24; do
  RAIN_ACCUM_HOURS="$accumulation_hours" \
    SHANGRAO_WRF_DIR="$WRF_DIR" \
    SHANGRAO_PNG_DIR="$PNG_DIR" \
    "$NCL_BIN" "$WEBSITE/rain_wrf_hour_bjt.ncl"
done

PNG_DIR="$PNG_DIR" IAPLACS_PREVIEW_FORCE=1 \
  "$WEBSITE/publish_wrf_montage_to_github.sh" "$RUN_PREFIX"
