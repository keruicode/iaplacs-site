#!/usr/bin/env bash

# Push a credential-free runtime snapshot to Tianhe. This deliberately deploys
# scripts and configuration inputs only; the Tianhe compute/data paths must be
# configured later before any forecast cron jobs are enabled there.
set -Eeuo pipefail

SCRIPT_PATH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_PATH_DIR/build_forecast_catalog.py" ]]; then
  SCRIPT_DIR="$SCRIPT_PATH_DIR"
else
  SCRIPT_DIR="$(cd "$SCRIPT_PATH_DIR/.." && pwd)"
fi
BACKUP_SCRIPT="${BACKUP_SCRIPT:-$SCRIPT_DIR/backup_iap_runtime.sh}"
BACKUP_ROOT="${BACKUP_ROOT:-$SCRIPT_DIR/backups/runtime}"
TIANHE_TARGET="${TIANHE_TARGET:-sunjm@192.168.4.11}"
TIANHE_ROOT="${TIANHE_ROOT:-/fs1/home/sunjm/kerui}"
CONNECT_TIMEOUT="${TIANHE_CONNECT_TIMEOUT:-20}"
STRICT_HOST_KEY_CHECKING="${TIANHE_STRICT_HOST_KEY_CHECKING:-yes}"

if [[ ! -x "$BACKUP_SCRIPT" ]]; then
  echo "ERROR: backup script is not executable: $BACKUP_SCRIPT" >&2
  exit 1
fi
if ! [[ "$CONNECT_TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: TIANHE_CONNECT_TIMEOUT must be a positive integer" >&2
  exit 64
fi
case "$STRICT_HOST_KEY_CHECKING" in
  yes|ask|no) ;;
  *)
    echo "ERROR: TIANHE_STRICT_HOST_KEY_CHECKING must be yes, ask, or no" >&2
    exit 64
    ;;
esac

BACKUP_ROOT="$BACKUP_ROOT" "$BACKUP_SCRIPT"
archive=""
while IFS= read -r candidate; do
  if [[ -z "$archive" || "$candidate" -nt "$archive" ]]; then
    archive="$candidate"
  fi
done < <(find "$BACKUP_ROOT" -maxdepth 1 -type f -name 'iaplacs-runtime-*.tar.gz' -print)
if [[ -z "$archive" || ! -f "$archive" ]]; then
  echo "ERROR: no runtime archive was created under $BACKUP_ROOT" >&2
  exit 1
fi

release_name="$(basename "$archive" .tar.gz)"
remote_root="${TIANHE_ROOT%/}/iaplacs-runtime"
remote_backup_dir="$remote_root/backups"
remote_release_dir="$remote_root/releases/$release_name"
remote_archive="$remote_backup_dir/$(basename "$archive")"
remote_checksum="$remote_backup_dir/$(basename "${archive}.sha256")"
remote_current="$remote_root/current"
ssh_options=(-o BatchMode=yes -o "ConnectTimeout=$CONNECT_TIMEOUT" -o "StrictHostKeyChecking=$STRICT_HOST_KEY_CHECKING")
ssh_command="ssh ${ssh_options[*]}"

remote_prepare="$(printf 'mkdir -p %q %q' "$remote_backup_dir" "$remote_release_dir")"
ssh "${ssh_options[@]}" "$TIANHE_TARGET" "$remote_prepare"
rsync -a --checksum -e "$ssh_command" "$archive" "${archive}.sha256" "$TIANHE_TARGET:$remote_backup_dir/"

remote_finish="$(printf 'tar -xzf %q -C %q && (cd %q && sha256sum -c %q) && if [ -e %q ] && [ ! -L %q ]; then echo %q >&2; exit 1; fi && ln -sfn %q %q' \
  "$remote_archive" "$remote_release_dir" "$remote_backup_dir" "$(basename "$remote_checksum")" "$remote_current" "$remote_current" \
  "ERROR: refusing to replace a non-symlink current path: $remote_current" "releases/$release_name" "$remote_current")"
ssh "${ssh_options[@]}" "$TIANHE_TARGET" "$remote_finish"

echo "TIANHE_RELEASE=$TIANHE_TARGET:$remote_release_dir"
echo "TIANHE_CURRENT=$TIANHE_TARGET:$remote_current"
