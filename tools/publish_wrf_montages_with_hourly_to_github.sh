#!/usr/bin/env bash

# Publish all current Shangrao montages, then attach hourly regional and
# national panels for every prefix listed by the active WRF pipeline.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONTAGE_PUBLISHER="${MONTAGE_PUBLISHER:-$SCRIPT_DIR/publish_wrf_montage_to_github.sh}"
HOURLY_PUBLISHER="${HOURLY_PUBLISHER:-$SCRIPT_DIR/publish_wrf_hourly_panels_to_oss.sh}"
PREFIX_FILE="${PREFIX_FILE:-$SCRIPT_DIR/latest_wrf_prefixes.txt}"

[[ -x "$MONTAGE_PUBLISHER" ]] || {
  echo "ERROR: montage publisher is not executable: $MONTAGE_PUBLISHER" >&2
  exit 1
}
[[ -x "$HOURLY_PUBLISHER" ]] || {
  echo "ERROR: hourly publisher is not executable: $HOURLY_PUBLISHER" >&2
  exit 1
}
[[ -s "$PREFIX_FILE" ]] || {
  echo "ERROR: WRF prefix file is empty or missing: $PREFIX_FILE" >&2
  exit 1
}

"$MONTAGE_PUBLISHER" --all-current

mapfile -t prefixes < <(sed '/^[[:space:]]*$/d' "$PREFIX_FILE" | sort -u)
for prefix in "${prefixes[@]}"; do
  if [[ ! "$prefix" =~ ^[0-9]{8}_[0-9]{2}$ ]]; then
    echo "WARNING: skipping invalid WRF prefix: $prefix" >&2
    continue
  fi
  "$HOURLY_PUBLISHER" "$prefix"
done
