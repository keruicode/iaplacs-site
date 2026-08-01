#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_PREFIX="${1:-}"
[[ "$RUN_PREFIX" =~ ^[0-9]{8}_[0-9]{2}$ ]] || {
  echo "Usage: publish_wrf_hourly_panels_to_oss.sh YYYYMMDD_HH" >&2
  exit 64
}

"$SCRIPT_DIR/publish_hourly_panels_to_oss.sh" \
  --family wrf_montage \
  --run-prefix "$RUN_PREFIX" \
  --regional-dir "${SHANGRAO_REGIONAL_PANEL_DIR:-$SCRIPT_DIR/wrf_hourly_png}" \
  --national-dir "${SHANGRAO_NATIONAL_PANEL_DIR:-$SCRIPT_DIR/national_hourly_png}"
