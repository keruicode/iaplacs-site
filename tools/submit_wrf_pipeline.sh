#!/usr/bin/env bash

# Submit the Shangrao render pipeline once. Environment overrides such as
# WORK_ROOT and IAPLACS_FORCE_RENDER are intentionally inherited by Slurm.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"
mkdir -p "$LOG_DIR"

JOB_NAME="${JOB_NAME:-wrf_web_pipeline}"
SLURM_PARTITION="${SLURM_PARTITION:-cpu_single}"
SLURM_TIME="${SLURM_TIME:-04:00:00}"
SLURM_CPUS_PER_TASK="${SLURM_CPUS_PER_TASK:-2}"
SLURM_MEM="${SLURM_MEM:-8G}"

# Cluster profiles reference variables absent from cron and Slurm shells.
set +u
if [[ -f /etc/profile ]]; then
  # shellcheck source=/dev/null
  source /etc/profile || echo "WARNING: /etc/profile returned a non-zero status" >&2
fi
if [[ -f "$HOME/.bashrc.minkerui" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.bashrc.minkerui" || echo "WARNING: $HOME/.bashrc.minkerui returned a non-zero status" >&2
fi
set -u
cd "$SCRIPT_DIR"

exec 9>"$LOG_DIR/submit.lock"
if ! flock -n 9; then
  echo "$(date '+%F %T') another submit process is active; skip"
  exit 0
fi

if squeue -h -u "$USER" -n "$JOB_NAME" -t PD,R,CG 2>/dev/null | grep -q .; then
  echo "$(date '+%F %T') $JOB_NAME already queued or running; skip"
  exit 0
fi

iap_home_dir="$(cd "$SCRIPT_DIR/.." && pwd)"
job_id="$(
  sbatch --parsable \
    --job-name="$JOB_NAME" \
    --partition="$SLURM_PARTITION" \
    --time="$SLURM_TIME" \
    --nodes=1 \
    --ntasks=1 \
    --cpus-per-task="$SLURM_CPUS_PER_TASK" \
    --mem="$SLURM_MEM" \
    --export="ALL,WEBSITE_DIR=$SCRIPT_DIR,IAP_HOME_DIR=$iap_home_dir" \
    --chdir="$SCRIPT_DIR" \
    --output="$LOG_DIR/slurm-%x-%j.out" \
    --error="$LOG_DIR/slurm-%x-%j.err" \
    "$SCRIPT_DIR/auto_pipeline_server.sh"
)"

echo "$(date '+%F %T') submitted $JOB_NAME as job $job_id"
