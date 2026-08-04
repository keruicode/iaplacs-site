#!/usr/bin/env bash

# Hourly publication auditor for IAP. It validates the public GitHub Pages
# catalog from server02, then repairs only incomplete already-rendered runs.
# Model directories under zhoubj are read-only inputs.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"
GITHUB_HOST="${GITHUB_HOST:-server02}"
PUBLIC_CATALOG_URL="${PUBLIC_CATALOG_URL:-https://iaplacs.xyz/data/current/forecast-runs.json}"
OUTPUT_AUDIT_RUNS="${OUTPUT_AUDIT_RUNS:-5}"
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

panel_windows() {
  local directory="$1" prefix="$2"
  [[ -d "$directory" ]] || return 0
  find "$directory" -maxdepth 1 -type f -name "${prefix}*rain_hour_*_BJT.png" -printf '%f\n' \
    | "$PYTHON_BIN" -c '
import re, sys
pattern = re.compile(r"_rain_hour_(\d{10})-(\d{10})_BJT\.png$")
windows = set()
for line in sys.stdin:
    match = pattern.search(line.strip())
    if match:
        windows.add(match.groups())
windows = sorted(windows)
print(",".join("%s-%s" % window for window in windows))
'
}

window_count() {
  local windows="$1"
  [[ -n "$windows" ]] || { printf '0\n'; return; }
  awk -F, '{ print NF }' <<<"$windows"
}

expected_first_start() {
  local run_time_basis="$1" run="$2"
  "$PYTHON_BIN" - "$run_time_basis" "$run" <<'PY'
from __future__ import print_function
import sys
from datetime import datetime, timedelta
basis, run = sys.argv[1:]
initial = datetime.strptime(run, "%Y%m%d_%H")
if basis == "utc":
    initial += timedelta(hours=8)
print((initial + timedelta(hours=12)).strftime("%Y%m%d%H"))
PY
}

sequence_is_valid() {
  local windows="$1" expected_first="$2"
  "$PYTHON_BIN" - "$windows" "$expected_first" <<'PY'
from __future__ import print_function
import sys
from datetime import datetime, timedelta
raw, expected = sys.argv[1:]
items = []
for value in filter(None, raw.split(",")):
    start, end = value.split("-")
    items.append((datetime.strptime(start, "%Y%m%d%H"), datetime.strptime(end, "%Y%m%d%H")))
if not items or items[0][0] != datetime.strptime(expected, "%Y%m%d%H"):
    raise SystemExit(1)
for index, (start, end) in enumerate(items):
    if end - start != timedelta(hours=1):
        raise SystemExit(1)
    if index and start != items[index - 1][1]:
        raise SystemExit(1)
PY
}

list_output_runs() {
  local root="$1"
  [[ -d "$root" ]] || return 0
  find "$root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | awk '/^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9]$/ { print }' \
    | sort -nr \
    | head -n "$OUTPUT_AUDIT_RUNS"
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

public_windows() {
  local service="$1" run_id="$2" frame_id="$3"
  "$PYTHON_BIN" - "$AUDIT_CATALOG" "$service" "$run_id" "$frame_id" <<'PY'
from __future__ import print_function
import json
import re
import sys

catalog_path, service, run_id, frame_id = sys.argv[1:]
with open(catalog_path, "r") as handle:
    payload = json.load(handle)
service_data = payload.get("services", {}).get(service, {})
run = next((item for item in service_data.get("runs", []) if item.get("id") == run_id), None)
if run is None:
    raise SystemExit("run-not-found")
target = None
for product in run.get("products", []):
    for frame in product.get("frames", []):
        if frame.get("id") == frame_id:
            target = frame
            break
if target is None:
    raise SystemExit("frame-not-found")
pattern = re.compile(r"_rain_hour_(\d{10})-(\d{10})_BJT\.webp(?:\?|$)")
windows = []
for item in target.get("individual_frames") or []:
    match = pattern.search(item.get("file", ""))
    if match:
        windows.append(match.groups())
print(",".join("%s-%s" % window for window in sorted(set(windows))))
PY
}

local_sequences_are_valid() {
  local basis="$1" run="$2" region="$3" national="$4" expected
  expected="$(expected_first_start "$basis" "$run")"
  [[ -n "$region" && "$region" == "$national" ]] || return 1
  sequence_is_valid "$region" "$expected"
}

audit_ningxia_output() {
  local run="$1" output="$SCRIPT_DIR/worknx_ningxia_overview/$run"
  local region national frozen public_region public_national public_frozen region_count national_count frozen_count
  region="$(panel_windows "$output/captioned_t13_t48" '')"
  national="$(panel_windows "$output/national_captioned_t13_t48" '')"
  frozen="$(panel_windows "$output/frozen_captioned_t13_t48" '')"
  region_count="$(window_count "$region")"
  national_count="$(window_count "$national")"
  frozen_count="$(window_count "$frozen")"
  if ! local_sequences_are_valid utc "$run" "$region" "$national"; then
    log "NINGXIA $run local sequence invalid: region=$region_count national=$national_count; rerender latest run"
    run_action "$SCRIPT_DIR/publish_worknx_ningxia_to_github.sh" --latest
    return
  fi
  if [[ -n "$frozen" ]] && ! local_sequences_are_valid utc "$run" "$region" "$frozen"; then
    log "NINGXIA $run hail-warning sequence invalid: region=$region_count frozen=$frozen_count; rerender latest run"
    run_action "$SCRIPT_DIR/publish_worknx_ningxia_to_github.sh" --latest
    return
  fi
  public_region="$(public_windows ningxia "$run" ningxia_region 2>/dev/null || true)"
  public_national="$(public_windows ningxia "$run" worknx_national 2>/dev/null || true)"
  public_frozen=""
  if [[ -n "$frozen" ]]; then
    public_frozen="$(public_windows ningxia "$run" ningxia_hail_warning 2>/dev/null || true)"
  fi
  if [[ "$public_region" == "$region" && "$public_national" == "$national" && "$public_frozen" == "$frozen" ]]; then
    log "NINGXIA $run verified: region=$region_count national=$national_count hail=$frozen_count first=${region%%,*}"
    return
  fi
  log "NINGXIA $run public sequence mismatch; republish region=$region_count national=$national_count hail=$frozen_count first=${region%%,*}"
  run_action "$SCRIPT_DIR/publish_worknx_ningxia_to_github.sh" --output-run "$run"
}

audit_xinjiang_output() {
  local run="$1" output="$SCRIPT_DIR/workxj_xinjiang_overview/$run"
  local region national public_region public_national region_count national_count
  region="$(panel_windows "$output/captioned_t13_t48" '')"
  national="$(panel_windows "$output/national_captioned_t13_t48" '')"
  region_count="$(window_count "$region")"
  national_count="$(window_count "$national")"
  if ! local_sequences_are_valid utc "$run" "$region" "$national"; then
    log "XINJIANG $run local sequence invalid: region=$region_count national=$national_count; rerender latest run"
    run_action "$SCRIPT_DIR/publish_workxj_xinjiang_to_github.sh" --latest
    return
  fi
  public_region="$(public_windows xinjiang "$run" xinjiang_region 2>/dev/null || true)"
  public_national="$(public_windows xinjiang "$run" workxj_national 2>/dev/null || true)"
  if [[ "$public_region" == "$region" && "$public_national" == "$national" ]]; then
    log "XINJIANG $run verified: region=$region_count national=$national_count first=${region%%,*}"
    return
  fi
  log "XINJIANG $run public sequence mismatch; republish region=$region_count national=$national_count first=${region%%,*}"
  run_action "$SCRIPT_DIR/publish_workxj_xinjiang_to_github.sh" --output-run "$run"
}

audit_yunnan_output() {
  local run="$1" output="$SCRIPT_DIR/worknx_yunnan_airports_overview/$run"
  local region national public_region public_national region_count national_count
  region="$(panel_windows "$output/captioned_t13_t48" '')"
  national="$(panel_windows "$output/national_captioned_t13_t48" '')"
  region_count="$(window_count "$region")"
  national_count="$(window_count "$national")"
  if ! local_sequences_are_valid utc "$run" "$region" "$national"; then
    log "YUNNAN $run local sequence invalid: region=$region_count national=$national_count; rerender latest run"
    run_action "$SCRIPT_DIR/publish_worknx_yunnan_airports_to_github.sh" --latest
    return
  fi
  public_region="$(public_windows airport "airport_yunnan_$run" airport_region 2>/dev/null || true)"
  public_national="$(public_windows airport "airport_yunnan_$run" airport_national 2>/dev/null || true)"
  if [[ "$public_region" == "$region" && "$public_national" == "$national" ]]; then
    log "YUNNAN $run verified: region=$region_count national=$national_count first=${region%%,*}"
    return
  fi
  log "YUNNAN $run public sequence mismatch; republish region=$region_count national=$national_count first=${region%%,*}"
  run_action "$SCRIPT_DIR/publish_worknx_yunnan_airports_to_github.sh" --output-run "$run"
}

audit_shangrao_output() {
  local run="$1" region national public_region public_national region_count national_count
  region="$(panel_windows "$SCRIPT_DIR/wrf_hourly_png" "${run}_")"
  national="$(panel_windows "$SCRIPT_DIR/national_hourly_png" "${run}_national_")"
  region_count="$(window_count "$region")"
  national_count="$(window_count "$national")"
  if ! local_sequences_are_valid bjt "$run" "$region" "$national"; then
    log "SHANGRAO $run local sequence invalid: region=$region_count national=$national_count; submit forced rerender"
    run_action env IAPLACS_FORCE_RENDER=1 "$SCRIPT_DIR/submit_wrf_pipeline.sh"
    return
  fi
  public_region="$(public_windows shangrao "$run" shangrao_region 2>/dev/null || true)"
  public_national="$(public_windows shangrao "$run" shangrao_national 2>/dev/null || true)"
  if [[ "$public_region" == "$region" && "$public_national" == "$national" ]]; then
    log "SHANGRAO $run verified: region=$region_count national=$national_count first=${region%%,*}"
    return
  fi
  log "SHANGRAO $run public sequence mismatch; republish region=$region_count national=$national_count first=${region%%,*}"
  run_action "$SCRIPT_DIR/publish_wrf_montages_with_hourly_to_github.sh"
}

latest_completed_wrf() {
  local root="$1" run_dir candidate rsl
  while IFS= read -r run_dir; do
    candidate="$(find "$run_dir/gfs/wrf" -maxdepth 1 -type f -name 'wrfout_d01_*' -print 2>/dev/null | sort -r | head -n 1)"
    [[ -n "$candidate" ]] || continue
    rsl="$(dirname "$candidate")/rsl.error.0000"
    if [[ -f "$rsl" ]] && tail -n 200 "$rsl" | grep -q 'SUCCESS COMPLETE WRF'; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(
    find "$root" -mindepth 1 -maxdepth 1 -type d -name '20????????' -printf '%p\n' \
      | sort -r
  )
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
submit_missing_render xinjiang /data1/elpt_2022_00083/zhoubj/WORK_xj "$SCRIPT_DIR/workxj_xinjiang_overview" "$SCRIPT_DIR/publish_workxj_xinjiang_to_github.sh"
submit_missing_render yunnan /data1/elpt_2022_00083/zhoubj/WORK_yn "$SCRIPT_DIR/worknx_yunnan_airports_overview" "$SCRIPT_DIR/publish_worknx_yunnan_airports_to_github.sh"
submit_missing_render shangrao /data1/elpt_2022_00083/zhoubj/WORK '' ''

while IFS= read -r run; do
  [[ -n "$run" ]] && audit_ningxia_output "$run"
done < <(list_output_runs "$SCRIPT_DIR/worknx_ningxia_overview")
while IFS= read -r run; do
  [[ -n "$run" ]] && audit_xinjiang_output "$run"
done < <(list_output_runs "$SCRIPT_DIR/workxj_xinjiang_overview")
while IFS= read -r run; do
  [[ -n "$run" ]] && audit_yunnan_output "$run"
done < <(list_output_runs "$SCRIPT_DIR/worknx_yunnan_airports_overview")
if [[ -s "$SCRIPT_DIR/latest_wrf_prefixes.txt" ]]; then
  while IFS= read -r run; do
    [[ "$run" =~ ^[0-9]{8}_[0-9]{2}$ ]] && audit_shangrao_output "$run"
  done < "$SCRIPT_DIR/latest_wrf_prefixes.txt"
fi
log "publication audit finished"
