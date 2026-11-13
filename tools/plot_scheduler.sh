#!/usr/bin/env bash

# Shared scheduling boundary. No scientific imports or model reads here.
iaplacs_require_compute() {
  local node row owner state nodes allocated found=0
  node="$(hostname -s)" || return 1
  case "$node" in
    *login*|*ln[0-9]*|server*)
      echo "ERROR: plotting is forbidden on login/publish node $node" >&2
      return 1 ;;
  esac
  [[ "${SLURM_JOB_ID:-}" =~ ^[0-9]+$ ]] || {
    echo 'ERROR: a live Slurm allocation is required for plotting' >&2
    return 1
  }
  row="$(squeue -h -j "$SLURM_JOB_ID" -o '%u|%T|%N')" || return 1
  [[ -n "$row" && "$row" != *$'\n'* ]] || return 1
  IFS='|' read -r owner state nodes <<< "$row"
  [[ "$owner" == "$(id -un)" && "$state" == RUNNING ]] || return 1
  allocated="$(scontrol show hostnames "$nodes")" || return 1
  while IFS= read -r allocated; do
    [[ "${allocated%%.*}" == "$node" ]] && found=1
  done <<< "$allocated"
  [[ "$found" == 1 ]] || {
    echo "ERROR: $node is not in job $SLURM_JOB_ID allocation" >&2
    return 1
  }
  # Even small NumPy imports can otherwise create dozens of login-node threads.
  export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
  export BLIS_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1
  export MAGICK_THREAD_LIMIT=1
}

iaplacs_plot_entry() {
  local entry="$1"
  shift
  if [[ -n "${SLURM_JOB_ID:-}" ]]; then
    iaplacs_require_compute || exit 77
    return 0
  fi
  exec bash "$IAPLACS_SCRIPT_DIR/submit_plot_job.sh" "$entry" "$@"
}
