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
exec bash "$IAPLACS_SCRIPT_DIR/run_website_cycle.sh" --service "$service"
