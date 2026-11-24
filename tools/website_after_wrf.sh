#!/usr/bin/env bash
# Called inside the existing plot_rain allocation, never from a login shell.
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/runtime_paths.sh"
source "$IAPLACS_SCRIPT_DIR/plot_scheduler.sh"
iaplacs_require_compute || exit 77
root="$(iaplacs_runtime_root "$IAPLACS_SCRIPT_DIR")"
[[ -f "$root/config/website-wrf-hook.enabled" ]] || exit 0
path="${1:-}"
if [[ "$path" =~ ^/data1/elpt_2022_00083/zhoubj/(WORK|WORK_yn|WORK_xj)/([0-9]{10})/gfs$ ]]; then
  family="${BASH_REMATCH[1]}"
  run="${BASH_REMATCH[2]}"
else
  echo 'ERROR: unsupported WRF source directory' >&2
  exit 64
fi
case "$family" in
  WORK) service=ningxia ;;
  WORK_yn) service=yunnan ;;
  WORK_xj) service=xinjiang ;;
esac
printf '%s WRF hook service=%s run=%s job=%s\n' "$(date -Is)" "$service" "$run" "$SLURM_JOB_ID"
if [[ "$service" == ningxia ]]; then
  # The WRF allocation already exists. Never queue behind another region's audit.
  tail -n 200 "$path/wrf/rsl.error.0000" | grep 'SUCCESS COMPLETE WRF' >/dev/null || exit 75
  export PUBLISH_LOCK_WAIT_SECONDS=0
  bash "$IAPLACS_SCRIPT_DIR/publish_worknx_ningxia_to_github.sh" --run "${run:0:8}_${run:8:2}"
  if [[ -f "$root/config/ningxia-downloads.enabled" ]]; then
    exec bash "$IAPLACS_SCRIPT_DIR/publish_ningxia_downloads.sh" --run "$run"
  fi
  exit 0
fi
exec bash "$IAPLACS_SCRIPT_DIR/run_website_cycle.sh" --service "$service"
