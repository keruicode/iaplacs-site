#!/usr/bin/env bash
# Absence of a start-run file disables the product before Python or Slurm starts.
iaplacs_supercooled_enabled() {
  local root="$1" run="$2" start=""
  local config="${SUPERCOOLED_START_FILE:-$root/state/supercooled-start-run}"
  [[ -f "$config" ]] || return 1
  IFS= read -r start < "$config" || [[ -n "$start" ]] || return 1
  [[ "$start" =~ ^[0-9]{8}_[0-9]{2}$ && "$run" =~ ^[0-9]{8}_[0-9]{2}$ ]] || return 1
  [[ "$run" == "$start" || "$run" > "$start" ]]
}
