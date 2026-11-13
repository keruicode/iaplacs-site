#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/runtime_paths.sh"

[[ $# -ge 1 && -f "$1" ]] || { echo 'Usage: submit_plot_job.sh SCRIPT [ARGS...]' >&2; exit 64; }
entry="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
shift
case "$entry" in
  *.sh|*.py|*.ncl) ;;
  *) echo 'ERROR: expected a shell, Python or NCL script' >&2; exit 64 ;;
esac
[[ "$entry" == "$IAPLACS_SCRIPT_DIR/"* ]] || {
  echo 'ERROR: only Website scripts may be submitted by this launcher' >&2
  exit 64
}
root="$(iaplacs_runtime_root "$IAPLACS_SCRIPT_DIR")"
logs="$root/logs"
mkdir -p "$logs"
# One queue-wide submission lock; all jobs are named plot, never service names.
exec 9>"$logs/plot-submit.lock"
if flock -n 9; then
  :
else
  status=$?
  [[ "$status" == 1 ]] && exit 0
  echo "ERROR: submission lock failed: exit=$status" >&2
  exit "$status"
fi
key="$(printf '%s\0' "$entry" "$@" | cksum | awk '{print $1}')"
tag="iaplacs-plot:$key"
queue="$(squeue -h -u "$(id -un)" -o '%k')" || {
  echo 'ERROR: scheduler unavailable; no direct execution fallback' >&2
  exit 75
}
active=0
while IFS= read -r comment; do
  [[ "$comment" == "$tag" ]] && { echo 'plot already queued/running; skip'; exit 0; }
  [[ "$comment" == iaplacs-plot:* ]] && active=$((active + 1))
done <<< "$queue"
if (( active >= 1 )); then
  echo 'Website plot slot busy; retry on next cron tick'
  exit 75
fi
# The state file covers scheduler visibility lag immediately after sbatch.
receipt="$logs/plot-last-submit"
if [[ -f "$receipt" ]]; then
  read -r previous_id previous_epoch < "$receipt" || true
  now="$(date +%s)"
  if [[ "${previous_epoch:-}" =~ ^[0-9]+$ ]] && (( now - previous_epoch < 120 )); then
    echo 'Recent plot submission; wait for scheduler visibility'
    exit 0
  fi
fi
job="$(sbatch --parsable --job-name=plot \
  --comment="$tag" --partition="${IAPLACS_PLOT_PARTITION:-iap_nav}" \
  --nodes=1 --ntasks=1 --cpus-per-task="${IAPLACS_PLOT_CPUS:-2}" \
  --mem="${IAPLACS_PLOT_MEM:-16G}" --time="${IAPLACS_PLOT_TIME:-04:00:00}" \
  --export=ALL --chdir="$PWD" \
  --output="$logs/plot-%j.out" --error="$logs/plot-%j.err" \
  "$IAPLACS_SCRIPT_DIR/run_plot_job.sh" "$IAPLACS_SCRIPT_DIR" "$entry" "$@")"
[[ "$job" =~ ^[0-9]+(\;[A-Za-z0-9_.-]+)?$ ]] || {
  echo "ERROR: unrecognized sbatch result: $job" >&2
  exit 75
}
printf '%s %s\n' "$job" "$(date +%s)" > "$receipt.tmp.$$"
mv "$receipt.tmp.$$" "$receipt"
printf '%s job=%s name=plot entry=%s\n' "$(date -Is)" "$job" "$entry"
