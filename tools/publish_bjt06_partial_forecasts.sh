#!/usr/bin/env bash

# Publish an early, consistent snapshot of the previous UTC 06 run at 06 BJT.
# Normal publication must replace this snapshot after the WRF run completes.
set -Eeuo pipefail

SCRIPT_PATH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_PATH_DIR/build_forecast_catalog.py" ]]; then
  SCRIPT_DIR="$SCRIPT_PATH_DIR"
else
  SCRIPT_DIR="$(cd "$SCRIPT_PATH_DIR/.." && pwd)"
fi

WORK_ROOT="${WORK_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK}"
WORK_NX_ROOT="${WORK_NX_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK_nx}"
WORK_YN_ROOT="${WORK_YN_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK_yn}"
WORK_XJ_ROOT="${WORK_XJ_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK_xj}"
SNAPSHOT_ROOT="${SNAPSHOT_ROOT:-$SCRIPT_DIR/.partial_snapshots}"
STATE_DIR="${STATE_DIR:-$SCRIPT_DIR/state/bjt06_partial}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"
NCKS_BIN="${NCKS_BIN:-/public/software/apps/conda/latest/bin/ncks}"
NCDUMP_BIN="${NCDUMP_BIN:-/public/software/apps/conda/latest/bin/ncdump}"
PYTHON_BIN="${PYTHON_BIN:-/public/software/apps/conda/latest/bin/python3}"
MIN_TIME_COUNT="${MIN_TIME_COUNT:-14}"
SNAPSHOT_KEEP_RUNS="${SNAPSHOT_KEEP_RUNS:-2}"
SLURM_WAIT_SECONDS="${SLURM_WAIT_SECONDS:-14400}"
SUBMITTER="${SUBMITTER:-$SCRIPT_DIR/submit_wrf_pipeline.sh}"
SHANGRAO_PUBLISHER="${SHANGRAO_PUBLISHER:-$SCRIPT_DIR/publish_wrf_montages_with_hourly_to_github.sh}"

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $(basename "$0") [--dry-run]" >&2
  exit 64
fi

for value in "$MIN_TIME_COUNT" "$SNAPSHOT_KEEP_RUNS" "$SLURM_WAIT_SECONDS"; do
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || {
    echo "ERROR: numeric settings must be positive integers" >&2
    exit 64
  }
done

for pair in NCKS_BIN:ncks NCDUMP_BIN:ncdump PYTHON_BIN:python3; do
  variable="${pair%%:*}"
  command_name="${pair#*:}"
  candidate="${!variable}"
  if [[ ! -x "$candidate" ]]; then
    candidate="$(command -v "$command_name" || true)"
    printf -v "$variable" '%s' "$candidate"
  fi
  [[ -n "$candidate" && -x "$candidate" ]] || {
    echo "ERROR: required command not found: $command_name" >&2
    exit 127
  }
done

if [[ -z "${TARGET_RUN:-}" ]]; then
  target_date="$(TZ=Asia/Shanghai date -d yesterday +%Y%m%d)"
  TARGET_RUN="${target_date}06"
fi
[[ "$TARGET_RUN" =~ ^[0-9]{8}06$ ]] || {
  echo "ERROR: TARGET_RUN must use YYYYMMDD06: $TARGET_RUN" >&2
  exit 64
}

mkdir -p "$SNAPSHOT_ROOT" "$STATE_DIR" "$LOG_DIR"
exec 8>"$LOG_DIR/bjt06-partial.lock"
if ! flock -n 8; then
  echo "$(date '+%F %T') BJT 06 early publication is already running; skip"
  exit 0
fi

log() {
  printf '%s %s\n' "$(date '+%F %T')" "$*"
}

wrf_time_count() {
  "$NCDUMP_BIN" -h "$1" 2>/dev/null | awk '/Time = UNLIMITED/ && !seen { gsub(/[^0-9]/, "", $0); print; seen=1 }'
}

wrf_completed_successfully() {
  local rsl_file
  rsl_file="$(dirname "$1")/rsl.error.0000"
  [[ -f "$rsl_file" ]] && tail -n 200 "$rsl_file" | grep -q 'SUCCESS COMPLETE WRF'
}

expected_hourly_count() {
  local time_count="$1" expected
  expected=$((time_count - 13))
  (( expected > 36 )) && expected=36
  printf '%s\n' "$expected"
}

rendered_hourly_count() {
  local family="$1" utc_prefix bjt_prefix directory name_pattern
  utc_prefix="${TARGET_RUN:0:8}_${TARGET_RUN:8:2}"
  case "$family" in
    ningxia)
      directory="$SCRIPT_DIR/worknx_ningxia_overview/$utc_prefix/captioned_t13_t48"
      name_pattern='*_rain_hour_*_BJT.png'
      ;;
    yunnan)
      directory="$SCRIPT_DIR/worknx_yunnan_airports_overview/$utc_prefix/captioned_t13_t48"
      name_pattern='*_rain_hour_*_BJT.png'
      ;;
    xinjiang)
      directory="$SCRIPT_DIR/workxj_xinjiang_overview/$utc_prefix/captioned_t13_t48"
      name_pattern='*_rain_hour_*_BJT.png'
      ;;
    shangrao)
      bjt_prefix="$("$PYTHON_BIN" - "$TARGET_RUN" <<'PY'
from datetime import datetime, timedelta
import sys
print((datetime.strptime(sys.argv[1], "%Y%m%d%H") + timedelta(hours=8)).strftime("%Y%m%d_%H"))
PY
)"
      directory="$SCRIPT_DIR/wrf_hourly_png"
      name_pattern="${bjt_prefix}_*rain_hour_*_BJT.png"
      ;;
  esac
  if [[ ! -d "$directory" ]]; then
    printf '0\n'
    return
  fi
  find "$directory" -maxdepth 1 -type f -name "$name_pattern" -printf '%f\n' \
    | sort -u | awk 'END { print NR + 0 }'
}

state_value() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 0
  sed -n "s/^${key}=//p" "$file" | tail -n 1
}

write_state() {
  local marker="$1" family="$2" source="$3" snapshot="$4" time_count="$5" complete="$6"
  local temporary="${marker}.tmp.$$"
  {
    printf 'family=%s\n' "$family"
    printf 'target_run=%s\n' "$TARGET_RUN"
    if [[ "$complete" == "1" ]]; then printf 'status=complete\n'; else printf 'status=partial\n'; fi
    printf 'source=%s\n' "$source"
    printf 'source_size=%s\n' "$(stat -c '%s' "$source")"
    printf 'source_mtime=%s\n' "$(stat -c '%Y' "$source")"
    printf 'source_time_count=%s\n' "$time_count"
    printf 'source_complete=%s\n' "$complete"
    printf 'snapshot=%s\n' "$snapshot"
    printf 'published_at=%s\n' "$(date '+%F %T %Z')"
  } > "$temporary"
  mv -f "$temporary" "$marker"
}

prune_snapshots() {
  local family_root="$1"
  mapfile -t old_runs < <(
    find "$family_root" -mindepth 1 -maxdepth 1 -type d -name '20????????' -printf '%p\n' \
      | sort -r | tail -n "+$((SNAPSHOT_KEEP_RUNS + 1))"
  )
  if (( ${#old_runs[@]} )); then
    rm -rf -- "${old_runs[@]}"
  fi
}

# Sets PREP_* globals. Return 2 when no publication is needed yet.
prepare_snapshot() {
  local family="$1" model_root="$2" stamp source time_count complete marker marker_complete
  local family_root run_dir snapshot temporary variables optional snapshot_count attempt expected_count rendered_count
  stamp="${TARGET_RUN:0:4}-${TARGET_RUN:4:2}-${TARGET_RUN:6:2}_${TARGET_RUN:8:2}:00:00"
  source="$model_root/$TARGET_RUN/gfs/wrf/wrfout_d01_$stamp"
  marker="$STATE_DIR/${family}-${TARGET_RUN}.state"
  if [[ ! -f "$source" ]]; then
    log "$family: source not available yet: $source"
    return 2
  fi
  time_count="$(wrf_time_count "$source")"
  if [[ ! "$time_count" =~ ^[0-9]+$ ]] || (( time_count < MIN_TIME_COUNT )); then
    log "$family: T13 is not available yet; Time=${time_count:-unreadable}"
    return 2
  fi
  complete=0
  wrf_completed_successfully "$source" && complete=1
  marker_complete="$(state_value "$marker" source_complete)"
  if [[ "$marker_complete" == "1" ]]; then
    log "$family: completed early publication already recorded for $TARGET_RUN"
    return 2
  fi
  if [[ -f "$marker" && "$complete" != "1" ]]; then
    log "$family: partial publication already recorded; wait for WRF completion"
    return 2
  fi
  if [[ "$complete" == "1" ]]; then
    expected_count="$(expected_hourly_count "$time_count")"
    rendered_count="$(rendered_hourly_count "$family")"
    if [[ "$rendered_count" == "$expected_count" ]]; then
      log "$family: completed local render already has $rendered_count/$expected_count panels; no early redraw needed"
      if (( ! DRY_RUN )); then
        write_state "$marker" "$family" "$source" existing-complete-output "$time_count" 1
      fi
      return 2
    fi
  fi

  family_root="$SNAPSHOT_ROOT/$family"
  run_dir="$family_root/$TARGET_RUN/gfs/wrf"
  snapshot="$run_dir/wrfout_d01_$stamp"
  log "$family: prepare snapshot; Time=$time_count complete=$complete source=$source"
  PREP_FAMILY="$family"
  PREP_FAMILY_ROOT="$family_root"
  PREP_SOURCE="$source"
  PREP_SNAPSHOT="$snapshot"
  PREP_TIME_COUNT="$time_count"
  PREP_COMPLETE="$complete"
  PREP_MARKER="$marker"
  (( DRY_RUN )) && return 0

  mkdir -p "$run_dir"
  temporary="${snapshot}.tmp.$$"
  rm -f -- "$temporary"
  variables="Times,XLAT,XLONG,RAINNC,RAINC"
  for optional in GRAUPELNC HAILNC; do
    if "$NCKS_BIN" -m -v "$optional" "$source" >/dev/null 2>&1; then
      variables+=",$optional"
    fi
  done
  for attempt in 1 2 3; do
    if "$NCKS_BIN" -O -d "Time,0,$((time_count - 1))" -v "$variables" "$source" "$temporary"; then
      snapshot_count="$(wrf_time_count "$temporary")"
      [[ "$snapshot_count" == "$time_count" ]] && break
    fi
    rm -f -- "$temporary"
    log "$family: snapshot attempt $attempt failed; retry"
    sleep 20
  done
  if [[ ! -f "$temporary" ]] || [[ "$(wrf_time_count "$temporary")" != "$time_count" ]]; then
    rm -f -- "$temporary"
    log "$family: failed to create a consistent snapshot"
    return 1
  fi
  mv -f "$temporary" "$snapshot"
  prune_snapshots "$family_root"
}

publish_direct() {
  local family="$1" family_root="$2"
  case "$family" in
    ningxia)
      env WORK_NX_ROOT="$family_root" MIN_WRFOUT_BYTES=1 MIN_FILE_AGE_SECONDS=0 \
        "$SCRIPT_DIR/publish_worknx_ningxia_to_github.sh" --latest ;;
    yunnan)
      env WORK_YN_ROOT="$family_root" MIN_WRFOUT_BYTES=1 MIN_FILE_AGE_SECONDS=0 \
        "$SCRIPT_DIR/publish_worknx_yunnan_airports_to_github.sh" --latest ;;
    xinjiang)
      env WORK_XJ_ROOT="$family_root" MIN_WRFOUT_BYTES=1 MIN_FILE_AGE_SECONDS=0 \
        "$SCRIPT_DIR/publish_workxj_xinjiang_to_github.sh" --latest ;;
  esac
}

wait_for_shangrao() {
  local job_id="$1" expected_prefix deadline state
  expected_prefix="$("$PYTHON_BIN" - "$TARGET_RUN" <<'PY'
from datetime import datetime, timedelta
import sys
print((datetime.strptime(sys.argv[1], "%Y%m%d%H") + timedelta(hours=8)).strftime("%Y%m%d_%H"))
PY
)"
  deadline=$(( $(date +%s) + SLURM_WAIT_SECONDS ))
  while squeue -h -j "$job_id" 2>/dev/null | grep -q .; do
    (( $(date +%s) < deadline )) || {
      log "shangrao: timed out waiting for Slurm job $job_id"
      return 75
    }
    sleep 30
  done
  state="$(sacct -n -X -j "$job_id" --format=State 2>/dev/null | awk 'NF { print $1; exit }' || true)"
  if [[ -n "$state" && "$state" != COMPLETED* ]]; then
    log "shangrao: Slurm job $job_id ended in state $state"
    return 1
  fi
  if [[ ! -s "$SCRIPT_DIR/latest_wrf_prefixes.txt" ]] || ! grep -qx "$expected_prefix" "$SCRIPT_DIR/latest_wrf_prefixes.txt"; then
    log "shangrao: job $job_id did not produce expected prefix $expected_prefix"
    return 1
  fi
  "$SHANGRAO_PUBLISHER"
}

log "BJT 06 early publication started; target UTC run=$TARGET_RUN dry_run=$DRY_RUN"
shangrao_job_id=""
shangrao_ready=0

# Start Shangrao on Slurm, then render other services while that job runs.
if prepare_snapshot shangrao "$WORK_ROOT"; then
  if (( DRY_RUN )); then
    log "shangrao: would submit $PREP_SNAPSHOT and publish after completion"
  else
    SHANGRAO_SOURCE="$PREP_SOURCE"
    SHANGRAO_SNAPSHOT="$PREP_SNAPSHOT"
    SHANGRAO_TIME_COUNT="$PREP_TIME_COUNT"
    SHANGRAO_COMPLETE="$PREP_COMPLETE"
    SHANGRAO_MARKER="$PREP_MARKER"
    submit_output="$(env WORK_ROOT="$PREP_FAMILY_ROOT" MIN_WRFOUT_BYTES=1 MIN_FILE_AGE_SECONDS=0 IAPLACS_FORCE_RENDER=1 "$SUBMITTER")"
    printf '%s\n' "$submit_output"
    shangrao_job_id="$(sed -n -E 's/.* submitted .* as job ([0-9]+).*/\1/p' <<<"$submit_output" | tail -n 1)"
    if [[ -n "$shangrao_job_id" ]]; then
      shangrao_ready=1
    else
      log "shangrao: no new Slurm job submitted; retry later"
    fi
  fi
fi

# WORK_yn must never publish an incomplete snapshot: its panel count controls
# the airport page layout. Completed Yunnan runs publish through the normal
# frequent checker; the other early-morning services retain this snapshot path.
for family in ningxia xinjiang; do
  case "$family" in
    ningxia) model_root="$WORK_NX_ROOT" ;;
    yunnan) model_root="$WORK_YN_ROOT" ;;
    xinjiang) model_root="$WORK_XJ_ROOT" ;;
  esac
  if prepare_snapshot "$family" "$model_root"; then
    if (( DRY_RUN )); then
      log "$family: would render and publish $PREP_SNAPSHOT"
    else
      publish_direct "$family" "$PREP_FAMILY_ROOT"
      write_state "$PREP_MARKER" "$family" "$PREP_SOURCE" "$PREP_SNAPSHOT" "$PREP_TIME_COUNT" "$PREP_COMPLETE"
      log "$family: early publication recorded; Time=$PREP_TIME_COUNT complete=$PREP_COMPLETE"
    fi
  fi
done

if (( shangrao_ready )); then
  wait_for_shangrao "$shangrao_job_id"
  write_state "$SHANGRAO_MARKER" shangrao "$SHANGRAO_SOURCE" "$SHANGRAO_SNAPSHOT" "$SHANGRAO_TIME_COUNT" "$SHANGRAO_COMPLETE"
  log "shangrao: early publication recorded; Time=$SHANGRAO_TIME_COUNT complete=$SHANGRAO_COMPLETE"
fi

log "BJT 06 early publication finished; target UTC run=$TARGET_RUN"
