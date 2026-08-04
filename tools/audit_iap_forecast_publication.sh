#!/usr/bin/env bash

# Hourly publication auditor for IAP. It validates the public GitHub Pages
# catalog from server02, then repairs only incomplete already-rendered runs.
# Model directories under zhoubj are read-only inputs.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"
GITHUB_HOST="${GITHUB_HOST:-server02}"
PUBLIC_CATALOG_URL="${PUBLIC_CATALOG_URL:-https://iaplacs.xyz/data/current/forecast-runs.json}"
OUTPUT_AUDIT_RUNS="${OUTPUT_AUDIT_RUNS:-1}"
PYTHON_BIN="${PYTHON_BIN:-/public/software/apps/conda/latest/bin/python3}"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: audit_iap_forecast_publication.sh [--dry-run]

Checks the latest rendered IAP products against the public catalog. A missing
regional or nationwide hourly sequence is republished from its existing output
directory. Completed model runs that have not yet been rendered are submitted
to the normal Slurm pipeline.
EOF
}

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
elif [[ -n "${1:-}" ]]; then
  usage >&2
  exit 64
fi

[[ "$OUTPUT_AUDIT_RUNS" =~ ^[1-9][0-9]*$ ]] || {
  echo "ERROR: OUTPUT_AUDIT_RUNS must be a positive integer" >&2
  exit 64
}

mkdir -p "$LOG_DIR"
[[ -x "$PYTHON_BIN" ]] || PYTHON_BIN="$(command -v python3 || command -v python)"
exec 9>"$LOG_DIR/publication-audit.lock"
if ! flock -n 9; then
  echo "$(date '+%F %T') publication audit already running; skip"
  exit 0
fi

AUDIT_CATALOG="$(mktemp "${TMPDIR:-/tmp}/iaplacs-public-catalog.XXXXXX")"
cleanup() {
  rm -f -- "$AUDIT_CATALOG"
}
trap cleanup EXIT

log() {
  printf '%s %s\n' "$(date '+%F %T')" "$*"
}

run_action() {
  if (( DRY_RUN )); then
    log "DRY-RUN: $*"
    return 0
  fi
  log "RUN: $*"
  "$@"
}

count_panels() {
  local directory="$1" prefix="$2"
  [[ -d "$directory" ]] || { printf '0\n'; return; }
  find "$directory" -maxdepth 1 -type f -name "${prefix}*rain_hour_*_BJT.png" | wc -l | tr -d '[:space:]'
}

list_output_runs() {
  local root="$1"
  [[ -d "$root" ]] || return 0
  find "$root" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' \
    | awk '$2 ~ /^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9]$/ { print }' \
    | sort -nr \
    | head -n "$OUTPUT_AUDIT_RUNS" \
    | cut -d' ' -f2-
}

# IAP itself has no public DNS. Fetch the browser-facing catalog once through
# server02; parsing it locally avoids many slow SSH logins in a single audit.
fetch_public_catalog() {
  local cache_buster url
  cache_buster="audit=$(date +%s)-$$"
  url="${PUBLIC_CATALOG_URL}?${cache_buster}"
  if command -v timeout >/dev/null 2>&1; then
    timeout 90 ssh -o BatchMode=yes -o ConnectTimeout=30 "$GITHUB_HOST" \
      "curl -fsS --max-time 45 '$url'" > "$AUDIT_CATALOG"
  else
    ssh -o BatchMode=yes -o ConnectTimeout=30 "$GITHUB_HOST" \
      "curl -fsS --max-time 45 '$url'" > "$AUDIT_CATALOG"
  fi
  "$PYTHON_BIN" -m json.tool "$AUDIT_CATALOG" >/dev/null
}

public_counts() {
  local service="$1" run_id="$2"
  shift 2
  "$PYTHON_BIN" - "$AUDIT_CATALOG" "$service" "$run_id" "$@" <<'PY'
from __future__ import print_function
import json
import sys

catalog_path, service, run_id = sys.argv[1:4]
frame_ids = sys.argv[4:]
with open(catalog_path, "r") as handle:
    payload = json.load(handle)
service_data = payload.get("services", {}).get(service, {})
run = next((item for item in service_data.get("runs", []) if item.get("id") == run_id), None)
if run is None:
    raise SystemExit("run-not-found")
counts = {frame_id: 0 for frame_id in frame_ids}
for product in run.get("products", []):
    for frame in product.get("frames", []):
        frame_id = frame.get("id")
        if frame_id in counts:
            counts[frame_id] = len(frame.get("individual_frames") or [])
print(" ".join("%s=%s" % (frame_id, counts[frame_id]) for frame_id in frame_ids))
PY
}

counts_match() {
  local actual="$1" expected_region="$2" expected_national="$3" region_id="$4" national_id="$5"
  local actual_region actual_national
  actual_region="$(sed -n -E "s/.*${region_id}=([0-9]+).*/\\1/p" <<<"$actual")"
  actual_national="$(sed -n -E "s/.*${national_id}=([0-9]+).*/\\1/p" <<<"$actual")"
  [[ "$actual_region" == "$expected_region" && "$actual_national" == "$expected_national" ]]
}

audit_ningxia_output() {
  local run="$1" output="$SCRIPT_DIR/worknx_ningxia_overview/$run"
  local region national public
  region="$(count_panels "$output/captioned_t13_t48" '')"
  national="$(count_panels "$output/national_captioned_t13_t48" '')"
  if (( region == 0 || national == 0 )); then
    log "NINGXIA $run local output incomplete: region=$region national=$national"
    return
  fi
  if ! public="$(public_counts ningxia "$run" ningxia_region worknx_national)"; then
    log "NINGXIA $run public catalog unavailable; leaving existing data untouched"
    return
  fi
  if counts_match "$public" "$region" "$national" ningxia_region worknx_national; then
    log "NINGXIA $run verified: $public"
    return
  fi
  log "NINGXIA $run mismatch local region=$region national=$national public=[$public]"
  run_action "$SCRIPT_DIR/publish_worknx_ningxia_to_github.sh" --output-run "$run"
}

audit_yunnan_output() {
  local run="$1" output="$SCRIPT_DIR/worknx_yunnan_airports_overview/$run"
  local region national public
  region="$(count_panels "$output/captioned_t13_t48" '')"
  national="$(count_panels "$output/national_captioned_t13_t48" '')"
  if (( region == 0 || national == 0 )); then
    log "YUNNAN $run local output incomplete: region=$region national=$national"
    return
  fi
  if ! public="$(public_counts airport "airport_yunnan_$run" airport_region airport_national)"; then
    log "YUNNAN $run public catalog unavailable; leaving existing data untouched"
    return
  fi
  if counts_match "$public" "$region" "$national" airport_region airport_national; then
    log "YUNNAN $run verified: $public"
    return
  fi
  log "YUNNAN $run mismatch local region=$region national=$national public=[$public]"
  run_action "$SCRIPT_DIR/publish_worknx_yunnan_airports_to_github.sh" --output-run "$run"
}

audit_shangrao_output() {
  local run="$1" region national public
  region="$(count_panels "$SCRIPT_DIR/wrf_hourly_png" "${run}_")"
  national="$(count_panels "$SCRIPT_DIR/national_hourly_png" "${run}_national_")"
  if (( region == 0 || national == 0 )); then
    log "SHANGRAO $run local output incomplete: region=$region national=$national"
    return
  fi
  if ! public="$(public_counts shangrao "$run" shangrao_region shangrao_national)"; then
    log "SHANGRAO $run public catalog unavailable; leaving existing data untouched"
    return
  fi
  if counts_match "$public" "$region" "$national" shangrao_region shangrao_national; then
    log "SHANGRAO $run verified: $public"
    return
  fi
  log "SHANGRAO $run mismatch local region=$region national=$national public=[$public]"
  run_action "$SCRIPT_DIR/publish_wrf_montages_with_hourly_to_github.sh"
}

latest_completed_wrf() {
  local root="$1" candidate rsl
  while IFS= read -r candidate; do
    rsl="$(dirname "$candidate")/rsl.error.0000"
    if [[ -f "$rsl" ]] && tail -n 200 "$rsl" | grep -q 'SUCCESS COMPLETE WRF'; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(find "$root" -mindepth 4 -maxdepth 4 -type f -name 'wrfout_d01_*' -printf '%p\n' | sort -r)
  return 1
}

utc_wrf_prefix() {
  local source="$1" stamp
  stamp="$(basename "$source" | sed -n -E 's/^wrfout_d01_([0-9]{4})-([0-9]{2})-([0-9]{2})_([0-9]{2}):00:00$/\1\2\3_\4/p')"
  [[ -n "$stamp" ]] && printf '%s\n' "$stamp"
}

bjt_wrf_prefix() {
  local utc_prefix="$1"
  /public/software/apps/conda/latest/bin/python3 - "$utc_prefix" <<'PY'
from __future__ import print_function
import sys
from datetime import datetime, timedelta
print((datetime.strptime(sys.argv[1], "%Y%m%d_%H") + timedelta(hours=8)).strftime("%Y%m%d_%H"))
PY
}

submit_missing_render() {
  local family="$1" model_root="$2" output_root="$3" renderer="$4" prefix source expected
  source="$(latest_completed_wrf "$model_root" || true)"
  [[ -n "$source" ]] || return
  prefix="$(utc_wrf_prefix "$source")"
  [[ -n "$prefix" ]] || return
  expected="$prefix"
  if [[ "$family" == "shangrao" ]]; then
    expected="$(bjt_wrf_prefix "$prefix")"
    if [[ -s "$SCRIPT_DIR/latest_wrf_prefixes.txt" ]] && grep -qx "$expected" "$SCRIPT_DIR/latest_wrf_prefixes.txt"; then
      return
    fi
  elif [[ -d "$output_root/$expected" ]]; then
    return
  fi
  log "${family^^} completed model output $prefix has no rendered product $expected"
  if [[ "$family" == "shangrao" ]]; then
    run_action "$SCRIPT_DIR/submit_wrf_pipeline.sh"
  else
    run_action "$renderer" --latest
  fi
}

log "publication audit started (dry_run=$DRY_RUN)"
if ! fetch_public_catalog; then
  log "public catalog fetch through $GITHUB_HOST failed; skip repairs this hour"
  exit 75
fi
submit_missing_render ningxia /data1/elpt_2022_00083/zhoubj/WORK_nx "$SCRIPT_DIR/worknx_ningxia_overview" "$SCRIPT_DIR/publish_worknx_ningxia_to_github.sh"
submit_missing_render yunnan /data1/elpt_2022_00083/zhoubj/WORK_yn "$SCRIPT_DIR/worknx_yunnan_airports_overview" "$SCRIPT_DIR/publish_worknx_yunnan_airports_to_github.sh"
submit_missing_render shangrao /data1/elpt_2022_00083/zhoubj/WORK '' ''

while IFS= read -r run; do
  [[ -n "$run" ]] && audit_ningxia_output "$run"
done < <(list_output_runs "$SCRIPT_DIR/worknx_ningxia_overview")
while IFS= read -r run; do
  [[ -n "$run" ]] && audit_yunnan_output "$run"
done < <(list_output_runs "$SCRIPT_DIR/worknx_yunnan_airports_overview")
if [[ -s "$SCRIPT_DIR/latest_wrf_prefixes.txt" ]]; then
  while IFS= read -r run; do
    [[ "$run" =~ ^[0-9]{8}_[0-9]{2}$ ]] && audit_shangrao_output "$run"
  done < "$SCRIPT_DIR/latest_wrf_prefixes.txt"
fi
log "publication audit finished"
