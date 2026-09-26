#!/usr/bin/env bash

# Preserve the legacy runtime root when launched from the organized directory.
if [[ -L "$(dirname "${BASH_SOURCE[0]}")/.runtime-root" ]]; then
  exec bash "$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.runtime-root" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@"
fi

set -Eeuo pipefail

set +u
source /etc/profile || true
if [ -f "$HOME/.bashrc.minkerui" ]; then
  source "$HOME/.bashrc.minkerui" || true
fi
set -u

wrf="/data1/elpt_2022_00083/zhoubj/WORK_yn/2026072912/gfs/wrf/wrfout_d01_2026-07-29_12:00:00"
echo "host=$(hostname)"
echo "ncdump=$(command -v ncdump)"
ncdump -h "$wrf" | awk '/Time = UNLIMITED/ { print; exit }'
echo "ncdump_status=$?"
tail -n 200 "$(dirname "$wrf")/rsl.error.0000" | grep 'SUCCESS COMPLETE WRF' | tail -n 1
echo "rsl_status=$?"
echo "ncl=$(command -v ncl)"
echo "montage=$(command -v montage)"
python3 -c 'from PIL import Image; print("pillow_webp=" + str(Image.registered_extensions().get(".webp")))'
