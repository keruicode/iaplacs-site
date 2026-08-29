#!/usr/bin/env bash

# Trigger catalog-aware OSS retention from IAP through server02, which has the
# stable outbound OSS route. Publishing and retention share one server02 lock.
set -Eeuo pipefail

SERVER02_HOST="${IAPLACS_SERVER02_HOST:-server02}"
REMOTE_PRUNE_SCRIPT="${IAPLACS_REMOTE_PRUNE_SCRIPT:-$HOME/bin/prune_iaplacs_oss.sh}"
SSH_BIN="${IAPLACS_SSH_BIN:-/usr/bin/ssh}"

[[ -x "$SSH_BIN" ]] || {
  echo "ERROR: SSH client is not executable: $SSH_BIN" >&2
  exit 1
}

env -u LD_LIBRARY_PATH -u LIBRARY_PATH -u LD_PRELOAD \
  "$SSH_BIN" -T -o BatchMode=yes -o ConnectTimeout=30 \
  -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
  "$SERVER02_HOST" /bin/bash -s -- "$REMOTE_PRUNE_SCRIPT" <<'REMOTE'
set -Eeuo pipefail

prune_script="$1"
lock_file="$HOME/.iaplacs-github-publish.lock"

[[ -x "$prune_script" ]] || {
  echo "ERROR: OSS retention script is not executable: $prune_script" >&2
  exit 1
}
command -v flock >/dev/null 2>&1 || {
  echo "ERROR: flock is required for OSS retention" >&2
  exit 1
}

exec 8>"$lock_file"
flock -w 1800 8 || {
  echo "ERROR: timed out waiting for the server02 publish lock" >&2
  exit 75
}

"$prune_script" --apply
REMOTE
