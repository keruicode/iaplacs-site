#!/usr/bin/env bash
set -Eeuo pipefail
# Slurm copies this file to its spool: never locate code relative to $0.
[[ $# -ge 2 && "$1" == /* && -f "$1/runtime_paths.sh" ]] || exit 64
source "$1/runtime_paths.sh"
shift
source "$IAPLACS_SCRIPT_DIR/plot_scheduler.sh"
iaplacs_require_compute || exit 77
printf '%s job=%s node=%s cpus=%s command=' \
  "$(date -Is)" "$SLURM_JOB_ID" "$(hostname -s)" "${SLURM_CPUS_PER_TASK:-unknown}"
printf '%q ' "$@"
printf '\n'
case "$1" in
  *.sh) exec bash "$@" ;;
  *.py) exec "${PYTHON_BIN:-/public/software/apps/conda/latest/bin/python3}" "$@" ;;
  *.ncl) exec "${NCL_BIN:-/public/software/apps/ncl_ncarg/ncl630/bin/ncl}" "$@" ;;
  *) echo 'ERROR: unsupported plot entry type' >&2; exit 64 ;;
esac
