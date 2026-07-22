#!/usr/bin/env bash

# Run on the local Mac when IAP cannot reach Tianhe directly. Tianhe accepts
# interactive shell commands and SFTP, so use SSH only for remote setup/checks
# and SFTP for the archive transfer.
set -Eeuo pipefail

IAP_TARGET="${IAP_TARGET:-10.64.201.2}"
IAP_ROOT="${IAP_ROOT:-/data1/elpt_2022_00083/kerui/Website}"
TIANHE_TARGET="${TIANHE_TARGET:-sunjm@192.168.4.11}"
TIANHE_ROOT="${TIANHE_ROOT:-/fs1/home/sunjm/kerui}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-60}"

if ! [[ "$CONNECT_TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: CONNECT_TIMEOUT must be a positive integer" >&2
  exit 64
fi

stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/iaplacs-tianhe-stage.XXXXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT

archive_path="$(
  ssh "$IAP_TARGET" "cd '$IAP_ROOT'; ./backup_iap_runtime.sh >/tmp/iaplacs-runtime-backup-now.log; ls -1t backups/runtime/iaplacs-runtime-*.tar.gz | head -n 1"
)"
if [[ -z "$archive_path" ]]; then
  echo "ERROR: IAP did not return a runtime archive path" >&2
  exit 1
fi

archive_name="$(basename "$archive_path")"
rsync -a \
  "$IAP_TARGET:$IAP_ROOT/$archive_path" \
  "$IAP_TARGET:$IAP_ROOT/${archive_path}.sha256" \
  "$stage_dir/"
(cd "$stage_dir" && sha256sum -c "${archive_name}.sha256")

release_name="${archive_name%.tar.gz}"
remote_root="${TIANHE_ROOT%/}/iaplacs-runtime"
ssh_options=(-tt -o BatchMode=yes -o "ConnectTimeout=$CONNECT_TIMEOUT" -o StrictHostKeyChecking=ask)

ssh "${ssh_options[@]}" "$TIANHE_TARGET" \
  "mkdir -p '$remote_root/backups' '$remote_root/releases/$release_name'"
printf 'put %s %s\nput %s %s\nquit\n' \
  "$stage_dir/$archive_name" "$remote_root/backups/$archive_name" \
  "$stage_dir/${archive_name}.sha256" "$remote_root/backups/${archive_name}.sha256" \
  | sftp -oBatchMode=yes -o"ConnectTimeout=$CONNECT_TIMEOUT" -oStrictHostKeyChecking=ask "$TIANHE_TARGET"

ssh "${ssh_options[@]}" "$TIANHE_TARGET" "
  set -e
  cd '$remote_root/backups'
  sha256sum -c '${archive_name}.sha256'
  tar -xzf '$archive_name' -C '$remote_root/releases/$release_name'
  if test -e '$remote_root/current' && ! test -L '$remote_root/current'; then
    echo 'ERROR: current is not a symlink' >&2
    exit 1
  fi
  ln -sfn 'releases/$release_name' '$remote_root/current'
  test -f '$remote_root/current/runtime/publish_worknx_ningxia_to_github.sh'
  test -f '$remote_root/current/runtime/publish_workyn_yunnan_airports_if_new.sh'
  test -f '$remote_root/current/runtime/rain_wrf_hour_bjt.ncl'
  test -f '$remote_root/current/runtime/SHP/yunnan_city.shp'
"

echo "TIANHE_CURRENT=$TIANHE_TARGET:$remote_root/current"
