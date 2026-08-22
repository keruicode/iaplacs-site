#!/usr/bin/env bash

# Cron-safe wrapper for the Yunnan airport WORK_yn product. It publishes only
# completed WRF runs and records their source signatures for cheap frequent checks.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_YN_ROOT="${WORK_YN_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK_yn}"
PUBLISHER="${PUBLISHER:-$SCRIPT_DIR/publish_worknx_yunnan_airports_to_github.sh}"
STATE_DIR="${STATE_DIR:-$SCRIPT_DIR/state}"
LAST_PREFIX_FILE="${LAST_PREFIX_FILE:-$STATE_DIR/yunnan_airport_last_published.txt}"
MIN_WRFOUT_BYTES="${MIN_WRFOUT_BYTES:-20000000000}"
MIN_TIME_COUNT="${MIN_TIME_COUNT:-14}"
NCDUMP_BIN="${NCDUMP_BIN:-/public/software/apps/conda/latest/bin/ncdump}"

dry_run=0
force=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    --force) force=1 ;;
    *)
      echo "Usage: $(basename "$0") [--dry-run] [--force]" >&2
      exit 64
      ;;
  esac
done

if [[ ! -d "$WORK_YN_ROOT" ]]; then
  echo "ERROR: WORK_YN_ROOT not found: $WORK_YN_ROOT" >&2
  exit 1
fi
if [[ ! -x "$PUBLISHER" ]]; then
  echo "ERROR: publisher is not executable: $PUBLISHER" >&2
  exit 1
fi
if [[ ! -x "$NCDUMP_BIN" ]]; then
  NCDUMP_BIN="$(command -v ncdump || true)"
fi
if [[ -z "$NCDUMP_BIN" || ! -x "$NCDUMP_BIN" ]]; then
  echo "ERROR: ncdump is required to inspect WORK_yn Time count" >&2
  exit 127
fi
if [[ ! "$MIN_TIME_COUNT" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: MIN_TIME_COUNT must be a positive integer" >&2
  exit 64
fi

mkdir -p "$STATE_DIR"
exec 6>"$STATE_DIR/yunnan_airport_check.lock"
if ! flock -n 6; then
  echo "$(date '+%F %T') Yunnan airport check already running; skip"
  exit 0
fi

latest_source=""
latest_prefix=""
latest_size=""
latest_epoch=""
latest_time_count=""
latest_complete=0
latest_regional_domain=""
latest_regional_size=""
latest_regional_epoch=""
latest_regional_time_count=""

wrf_time_count() {
  "$NCDUMP_BIN" -h "$1" 2>/dev/null | awk '/Time = UNLIMITED/ && !seen { gsub(/[^0-9]/, "", $0); print; seen=1 }'
}

wrf_completed_successfully() {
  local rsl_file
  rsl_file="$(dirname "$1")/rsl.error.0000"
  [[ -f "$rsl_file" ]] && tail -n 200 "$rsl_file" | grep -q 'SUCCESS COMPLETE WRF'
}

while IFS= read -r source_path; do
  source_epoch="$(stat -c '%Y' "$source_path")"
  source_size="$(stat -c '%s' "$source_path")"
  if (( source_size < MIN_WRFOUT_BYTES )); then
    continue
  fi
  time_count="$(wrf_time_count "$source_path")"
  [[ "$time_count" =~ ^[0-9]+$ ]] && (( time_count >= MIN_TIME_COUNT )) || continue
  if ! wrf_completed_successfully "$source_path"; then
    continue
  fi
  base="$(basename "$source_path")"
  if [[ "$base" =~ wrfout_d01_([0-9]{4})-([0-9]{2})-([0-9]{2})_([0-9]{2}):[0-9]{2}:[0-9]{2} ]]; then
    latest_prefix="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}_${BASH_REMATCH[4]}"
    latest_source="$source_path"
    latest_size="$source_size"
    latest_epoch="$source_epoch"
    latest_time_count="$time_count"
    latest_complete=1
    latest_regional_domain="d01"
    latest_regional_size="$source_size"
    latest_regional_epoch="$source_epoch"
    latest_regional_time_count="$time_count"
    nested_source="${source_path/wrfout_d01_/wrfout_d02_}"
    if [[ -f "$nested_source" ]]; then
      nested_time_count="$(wrf_time_count "$nested_source")"
      if [[ "$nested_time_count" =~ ^[0-9]+$ ]] && (( nested_time_count >= MIN_TIME_COUNT )); then
        latest_regional_domain="d02"
        latest_regional_size="$(stat -c '%s' "$nested_source")"
        latest_regional_epoch="$(stat -c '%Y' "$nested_source")"
        latest_regional_time_count="$nested_time_count"
      fi
    fi
    break
  fi
done < <(
  find "$WORK_YN_ROOT" -maxdepth 4 -type f \
    -name 'wrfout_d01_*' -printf '%p\n' \
    | sort -r
)

if [[ -z "$latest_prefix" ]]; then
  echo "No completed WORK_yn wrfout found."
  exit 0
fi

latest_signature="${latest_prefix}|${latest_size}|${latest_epoch}|${latest_time_count}|${latest_complete}|${latest_regional_domain}|${latest_regional_size}|${latest_regional_epoch}|${latest_regional_time_count}"
last_signature=""
if [[ -f "$LAST_PREFIX_FILE" ]]; then
  last_signature="$(tr -d '\r\n' < "$LAST_PREFIX_FILE")"
fi

if [[ "$force" != "1" && "$latest_signature" == "$last_signature" ]]; then
  echo "Yunnan airport source unchanged; run=$latest_prefix Time=$latest_time_count complete=$latest_complete source=$latest_source"
  exit 0
fi

if [[ "$dry_run" == "1" ]]; then
  echo "Would publish Yunnan airport run $latest_prefix; Time=$latest_time_count complete=$latest_complete source=$latest_source; previous=${last_signature:-none}"
  exit 0
fi

# Publish the exact completed source selected above.  The output root can still
# contain an older incomplete directory from before this guard was introduced;
# --latest would sort by output mtime and could republish that stale product.
"$PUBLISHER" --run "$latest_prefix"
printf '%s\n' "$latest_signature" > "$LAST_PREFIX_FILE"
echo "Recorded Yunnan airport source signature: $latest_signature"
