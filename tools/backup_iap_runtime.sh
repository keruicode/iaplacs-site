#!/usr/bin/env bash

# Create a small, restorable snapshot of the IAP website automation runtime.
# Forecast rasters, logs, Git metadata, credentials, and SSH keys stay out of
# the archive on purpose; they are either reproducible, large, or sensitive.
set -Eeuo pipefail

SCRIPT_PATH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_PATH_DIR/build_forecast_catalog.py" ]]; then
  SCRIPT_DIR="$SCRIPT_PATH_DIR"
else
  SCRIPT_DIR="$(cd "$SCRIPT_PATH_DIR/.." && pwd)"
fi
BACKUP_ROOT="${BACKUP_ROOT:-$SCRIPT_DIR/backups/runtime}"
IAP_HOME_DIR="${IAP_HOME_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
KEEP_DAYS="${IAPLACS_RUNTIME_BACKUP_KEEP:-14}"

if ! [[ "$KEEP_DAYS" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: IAPLACS_RUNTIME_BACKUP_KEEP must be a positive integer" >&2
  exit 64
fi

mkdir -p "$BACKUP_ROOT"
STAMP="$(date +%Y%m%d_%H%M%S)"
ARCHIVE="$BACKUP_ROOT/iaplacs-runtime-${STAMP}.tar.gz"
CHECKSUM="${ARCHIVE}.sha256"
STAGE_DIR="$(mktemp -d "$BACKUP_ROOT/.stage.XXXXXXXX")"
trap 'rm -rf "$STAGE_DIR"' EXIT

RUNTIME_DIR="$STAGE_DIR/runtime"
mkdir -p "$RUNTIME_DIR"

copy_if_exists() {
  local source="$1"
  local destination="$2"
  if [[ -e "$source" ]]; then
    mkdir -p "$(dirname "$destination")"
    cp -a "$source" "$destination"
  fi
}

while IFS= read -r -d '' source; do
  copy_if_exists "$source" "$RUNTIME_DIR/$(basename "$source")"
done < <(
  find "$SCRIPT_DIR" -maxdepth 1 -type f \
    \( -name '*.sh' -o -name '*.py' -o -name '*.ncl' -o -name 'AGENTS.md' \) \
    -print0
)

copy_if_exists "$SCRIPT_DIR/SHP" "$RUNTIME_DIR/SHP"
copy_if_exists "$SCRIPT_DIR/state" "$RUNTIME_DIR/state"
copy_if_exists "$SCRIPT_DIR/latest_wrf_outputs.txt" "$RUNTIME_DIR/latest_wrf_outputs.txt"
copy_if_exists "$SCRIPT_DIR/latest_wrf_prefixes.txt" "$RUNTIME_DIR/latest_wrf_prefixes.txt"
copy_if_exists "$IAP_HOME_DIR/batch_ncks.sh" "$STAGE_DIR/iap-home/batch_ncks.sh"

if crontab -l > "$STAGE_DIR/crontab.txt" 2>/dev/null; then
  :
else
  : > "$STAGE_DIR/crontab.txt"
fi

{
  echo "snapshot_time=$(date '+%F %T %Z')"
  echo "hostname=$(hostname)"
  echo "website_dir=$SCRIPT_DIR"
  echo "iap_home_dir=$IAP_HOME_DIR"
  echo "work_nx_root=/data1/elpt_2022_00083/zhoubj/WORK_nx"
  echo "work_yn_root=/data1/elpt_2022_00083/zhoubj/WORK_yn"
  echo "required_commands=ncks,ncl,montage,convert,python3,git,sbatch,squeue,rsync"
  echo "credential_files_excluded=~/.ssh,~/.iaplacs-oss.env"
  echo "large_data_excluded=wrfout_*,wrf_hourly_png,worknx_summary,worknx_ningxia_overview,worknx_yunnan_airports_overview,logs"
} > "$STAGE_DIR/runtime-paths.txt"

if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  {
    git -C "$SCRIPT_DIR" rev-parse HEAD
    git -C "$SCRIPT_DIR" status --short
  } > "$STAGE_DIR/git-state.txt"
  git -C "$SCRIPT_DIR" ls-files > "$STAGE_DIR/git-tracked-files.txt"
else
  echo "No Git worktree detected at $SCRIPT_DIR" > "$STAGE_DIR/git-state.txt"
fi

tar -C "$STAGE_DIR" -czf "$ARCHIVE" .
(cd "$BACKUP_ROOT" && sha256sum "$(basename "$ARCHIVE")") > "$CHECKSUM"

archives=()
while IFS= read -r archive_path; do
  archives+=("$archive_path")
done < <(ls -1t "$BACKUP_ROOT"/iaplacs-runtime-*.tar.gz 2>/dev/null || true)
if (( ${#archives[@]} > KEEP_DAYS )); then
  for old_archive in "${archives[@]:KEEP_DAYS}"; do
    rm -f -- "$old_archive" "${old_archive}.sha256"
  done
fi

echo "ARCHIVE=$ARCHIVE"
echo "CHECKSUM=$CHECKSUM"
