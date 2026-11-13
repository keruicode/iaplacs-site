#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/runtime_paths.sh"

root="$(iaplacs_runtime_root "$IAPLACS_SCRIPT_DIR")"
mkdir -p "$root/state/plot-cycle"
# Also exclude concurrent manual compute allocations, not just cron submissions.
exec 5>"$root/state/plot-cycle/run.lock"
if flock -n 5; then
  :
else
  status=$?
  [[ "$status" == 1 ]] && exit 75
  echo "ERROR: cycle lock failed: exit=$status" >&2
  exit "$status"
fi
failed=0
rotation="$root/state/plot-cycle/next-service"
start=0
[[ ! -f "$rotation" ]] || read -r start < "$rotation" || true
[[ "$start" =~ ^[012]$ ]] || start=0
# Advance before work: even a timed-out job must not starve later regions.
printf '%s\n' "$(((start + 1) % 3))" > "$rotation.tmp.$$"
mv "$rotation.tmp.$$" "$rotation"
run_stage() {
  local status
  # A subprocess keeps each script's errexit semantics intact.
  set +e
  bash "$@" </dev/null
  status=$?
  set -e
  if (( status != 0 )); then
    printf 'WARNING: stage=%s exit=%s; continuing other services\n' "$1" "$status" >&2
    failed=1
  fi
  return "$status"
}

hour="$(TZ=Asia/Shanghai date +%H)"
slot=$(( $(date +%s) / 900 ))
early_marker="$root/state/plot-cycle/early-slot"
last_slot=''
[[ ! -f "$early_marker" ]] || read -r last_slot < "$early_marker" || true
if [[ "$hour" == 06 || "$hour" == 07 ]] && [[ "$last_slot" != "$slot" ]]; then
  if run_stage "$IAPLACS_SCRIPT_DIR/publish_bjt06_partial_forecasts.sh"; then
    printf '%s\n' "$slot" > "$early_marker.tmp.$$"
    mv "$early_marker.tmp.$$" "$early_marker"
  fi
fi

services=(ningxia xinjiang yunnan)
for offset in 0 1 2; do
  service="${services[$(((start + offset) % 3))]}"
  # Preserve nested-grid/source-signature checks without a separate cron process.
  if [[ "$service" == yunnan ]]; then
    run_stage "$IAPLACS_SCRIPT_DIR/publish_workyn_yunnan_airports_if_new.sh" || true
  fi
  run_stage "$IAPLACS_SCRIPT_DIR/audit_iap_forecast_publication.sh" --service "$service" || true
done
exit "$failed"
