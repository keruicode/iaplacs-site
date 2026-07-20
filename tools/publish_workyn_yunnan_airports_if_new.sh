#!/usr/bin/env bash

# Cron-safe wrapper for the Yunnan airport WORK_yn product. It publishes only
# when a newer complete wrfout_d01 run is available, so hourly checks are cheap
# after the latest run has already been published.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_YN_ROOT="${WORK_YN_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK_yn}"
PUBLISHER="${PUBLISHER:-$SCRIPT_DIR/publish_worknx_yunnan_airports_to_github.sh}"
STATE_DIR="${STATE_DIR:-$SCRIPT_DIR/state}"
LAST_PREFIX_FILE="${LAST_PREFIX_FILE:-$STATE_DIR/yunnan_airport_last_published.txt}"
MIN_FILE_AGE_SECONDS="${MIN_FILE_AGE_SECONDS:-1200}"
MIN_WRFOUT_BYTES="${MIN_WRFOUT_BYTES:-20000000000}"

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

mkdir -p "$STATE_DIR"
now_epoch="$(date +%s)"
latest_source=""
latest_prefix=""

while IFS= read -r line; do
  source_epoch="${line%% *}"
  rest="${line#* }"
  source_size="${rest%% *}"
  source_path="${rest#* }"
  source_epoch="${source_epoch%.*}"
  if (( now_epoch - source_epoch < MIN_FILE_AGE_SECONDS )); then
    continue
  fi
  if (( source_size < MIN_WRFOUT_BYTES )); then
    continue
  fi
  base="$(basename "$source_path")"
  if [[ "$base" =~ wrfout_d01_([0-9]{4})-([0-9]{2})-([0-9]{2})_([0-9]{2}):[0-9]{2}:[0-9]{2} ]]; then
    latest_prefix="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}_${BASH_REMATCH[4]}"
    latest_source="$source_path"
    break
  fi
done < <(
  find "$WORK_YN_ROOT" -maxdepth 4 -type f \
    -name 'wrfout_d01_*' -printf '%T@ %s %p\n' \
    | sort -nr
)

if [[ -z "$latest_prefix" ]]; then
  echo "No complete stable WORK_yn wrfout found."
  exit 0
fi

last_prefix=""
if [[ -f "$LAST_PREFIX_FILE" ]]; then
  last_prefix="$(tr -d '[:space:]' < "$LAST_PREFIX_FILE")"
fi

if [[ "$force" != "1" && "$latest_prefix" == "$last_prefix" ]]; then
  echo "Yunnan airport run $latest_prefix already published; source=$latest_source"
  exit 0
fi

if [[ "$dry_run" == "1" ]]; then
  echo "Would publish Yunnan airport run $latest_prefix; source=$latest_source; previous=${last_prefix:-none}"
  exit 0
fi

"$PUBLISHER" --latest
printf '%s\n' "$latest_prefix" > "$LAST_PREFIX_FILE"
echo "Recorded Yunnan airport published run: $latest_prefix"
