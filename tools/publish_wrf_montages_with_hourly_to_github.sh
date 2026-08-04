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

PUBLISH_LOCK_FILE="${PUBLISH_LOCK_FILE:-$SCRIPT_DIR/logs/shangrao-publish.lock}"
PUBLISH_LOCK_WAIT_SECONDS="${PUBLISH_LOCK_WAIT_SECONDS:-14400}"
mkdir -p "$(dirname "$PUBLISH_LOCK_FILE")"
exec 7>"$PUBLISH_LOCK_FILE"
if ! flock -w "$PUBLISH_LOCK_WAIT_SECONDS" 7; then
  echo "ERROR: timed out waiting for Shangrao publication lock: $PUBLISH_LOCK_FILE" >&2
  exit 75
fi

"$MONTAGE_PUBLISHER" --all-current

mapfile -t prefixes < <(sed '/^[[:space:]]*$/d' "$PREFIX_FILE" | sort -u)
for prefix in "${prefixes[@]}"; do
  if [[ ! "$prefix" =~ ^[0-9]{8}_[0-9]{2}$ ]]; then
    echo "WARNING: skipping invalid WRF prefix: $prefix" >&2
    continue
  fi
  "$HOURLY_PUBLISHER" "$prefix"
done
