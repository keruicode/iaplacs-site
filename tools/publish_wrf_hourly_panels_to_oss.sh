#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_PREFIX="${1:-}"
[[ "$RUN_PREFIX" =~ ^[0-9]{8}_[0-9]{2}$ ]] || {
  echo "Usage: publish_wrf_hourly_panels_to_oss.sh YYYYMMDD_HH" >&2
  exit 64
}

regional_dir="${SHANGRAO_REGIONAL_PANEL_DIR:-$SCRIPT_DIR/wrf_hourly_png}"
national_dir="${SHANGRAO_NATIONAL_PANEL_DIR:-$SCRIPT_DIR/national_hourly_png}"
hail_dir="${SHANGRAO_HAIL_PANEL_DIR:-$SCRIPT_DIR/shangrao_hail_hourly_png}"

args=(
  --family wrf_montage
  --run-prefix "$RUN_PREFIX"
  --regional-dir "$regional_dir"
  --national-dir "$national_dir"
)
if [[ -d "$hail_dir" ]] && {
  compgen -G "$hail_dir/${RUN_PREFIX}_rain_hour_*_BJT.png" >/dev/null ||
    compgen -G "$hail_dir/${RUN_PREFIX}_shangrao_hail_warning_rain_hour_*_BJT.png" >/dev/null
}; then
  args+=(--extra-id shangrao_hail_warning --extra-dir "$hail_dir")
fi

"$SCRIPT_DIR/publish_hourly_panels_to_oss.sh" "${args[@]}"
