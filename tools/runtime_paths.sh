#!/usr/bin/env bash

# Code lives in scripts/ on IAP; data, logs and assets remain in Website/.
IAPLACS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

iaplacs_runtime_root() {
  local candidate="$1"
  if [[ -L "$candidate/.runtime-root" ]]; then
    (cd -P "$candidate/.runtime-root" && pwd)
  else
    printf '%s\n' "$candidate"
  fi
}

iaplacs_script_root() {
  local candidate="$1"
  if [[ -f "$candidate/scripts/runtime_paths.sh" ]]; then
    printf '%s/scripts\n' "$candidate"
  else
    printf '%s\n' "$candidate"
  fi
}
