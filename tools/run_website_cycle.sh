#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/runtime_paths.sh"

selected_service=""
if (( $# )); then
  [[ $# == 2 && "$1" == --service ]] || exit 64
  case "$2" in ningxia|xinjiang|yunnan) selected_service="$2" ;; *) exit 64 ;; esac
fi

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
  local status started=$SECONDS
  printf '%s stage=start command=%s\n' "$(date '+%FT%T%z')" "$*"
  # A subprocess keeps each script's errexit semantics intact.
  set +e
  bash "$@" </dev/null
  status=$?
  set -e
  printf '%s stage=end exit=%s elapsed_seconds=%s command=%s\n' \
    "$(date '+%FT%T%z')" "$status" "$((SECONDS - started))" "$*"
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
  [[ -z "$selected_service" || "$selected_service" == "$service" ]] || continue
  # Preserve nested-grid/source-signature checks without a separate cron process.
  if [[ "$service" == yunnan ]]; then
    run_stage "$IAPLACS_SCRIPT_DIR/publish_workyn_yunnan_airports_if_new.sh" || true
  fi
  OUTPUT_AUDIT_RUNS=1 MODEL_AUDIT_RUNS=1 run_stage \
    "$IAPLACS_SCRIPT_DIR/audit_iap_forecast_publication.sh" --service "$service" || true
done

# Current charts in every service take priority over NC and historical repairs.
if [[ -z "$selected_service" || "$selected_service" == ningxia ]] && \
   [[ -f "$root/config/ningxia-downloads.enabled" ]]; then
  run_stage "$IAPLACS_SCRIPT_DIR/publish_ningxia_downloads.sh" --recent 1 || true
fi

# One service's history every 20 minutes: a full rotation takes about an hour.
# No background workers; skip maintenance when current publication needs retry.
history_state="$root/state/plot-cycle/history-slot"
history_slot=$(( $(date +%s) / 1200 ))
previous_slot="$history_slot"
history_service=0
if [[ -f "$history_state" ]]; then
  read -r previous_slot history_service < "$history_state" || true
fi
[[ "$previous_slot" =~ ^[0-9]+$ ]] || previous_slot="$history_slot"
[[ "$history_service" =~ ^[012]$ ]] || history_service=0
if [[ -z "$selected_service" ]] && (( failed == 0 && previous_slot != history_slot )); then
  service="${services[$history_service]}"
  OUTPUT_AUDIT_RUNS=5 MODEL_AUDIT_RUNS=8 run_stage \
    "$IAPLACS_SCRIPT_DIR/audit_iap_forecast_publication.sh" --service "$service" || true
  if [[ "$service" == ningxia && -f "$root/config/ningxia-downloads.enabled" ]]; then
    run_stage "$IAPLACS_SCRIPT_DIR/publish_ningxia_downloads.sh" --recent 5 || true
  fi
  # Advance even after failure so one broken region cannot starve the others.
  history_service=$(((history_service + 1) % 3))
  previous_slot="$history_slot"
fi
if [[ -z "$selected_service" ]]; then
  printf '%s %s\n' "$previous_slot" "$history_service" > "$history_state.tmp.$$"
  mv "$history_state.tmp.$$" "$history_state"
fi
exit "$failed"
