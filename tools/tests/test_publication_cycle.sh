#!/usr/bin/env bash
# Shell-only orchestration regression; no network or scientific imports.
set -Eeuo pipefail
case "${0##*/}" in
  runtime_paths.sh)
    IAPLACS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    iaplacs_runtime_root() { printf '%s\n' "$MOCK_ROOT"; }
    return ;;
  flock) exit 0 ;;
  audit_iap_forecast_publication.sh|publish_ningxia_downloads.sh|publish_workyn_yunnan_airports_if_new.sh|publish_bjt06_partial_forecasts.sh)
    printf '%s|%s|%s|%s\n' "${0##*/}" "$*" "${OUTPUT_AUDIT_RUNS:-unset}" "${MODEL_AUDIT_RUNS:-unset}" >> "$MOCK_ROOT/calls"
    [[ "${MOCK_FAIL:-}" != "${0##*/}" ]] || exit 23
    exit 0 ;;
esac
tools="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export MOCK_ROOT="$work"
mkdir -p "$work/scripts" "$work/bin" "$work/config" "$work/state/plot-cycle"
cp "$tools/run_website_cycle.sh" "$work/scripts/"
# runtime_paths is sourced, so use a dedicated source-only fixture.
cp "$0" "$work/bin/flock"
chmod +x "$work/bin/flock"
export PATH="$work/bin:$PATH"
for name in audit_iap_forecast_publication.sh publish_ningxia_downloads.sh publish_workyn_yunnan_airports_if_new.sh publish_bjt06_partial_forecasts.sh; do
  cp "$0" "$work/scripts/$name"
done
cp "$tools/tests/publication_runtime_fixture.sh" "$work/scripts/runtime_paths.sh"
touch "$work/config/ningxia-downloads.enabled"
bash "$work/scripts/run_website_cycle.sh" > "$work/log"
[[ "$(grep -c 'audit_iap.*|1|1$' "$work/calls")" == 3 ]]
[[ "$(tail -n 1 "$work/calls")" == 'publish_ningxia_downloads.sh|--recent 1|unset|unset' ]]
! grep -q '|5|8$' "$work/calls"
printf '0 0\n' > "$work/state/plot-cycle/history-slot"
: > "$work/calls"
bash "$work/scripts/run_website_cycle.sh" >> "$work/log"
[[ "$(grep -c 'audit_iap.*|1|1$' "$work/calls")" == 3 ]]
grep -q '^audit_iap_forecast_publication.sh|--service ningxia|5|8$' "$work/calls"
[[ "$(tail -n 1 "$work/calls")" == 'publish_ningxia_downloads.sh|--recent 5|unset|unset' ]]
: > "$work/calls"
bash "$work/scripts/run_website_cycle.sh" >> "$work/log"
! grep -q '|5|8$' "$work/calls"
printf '0 1\n' > "$work/state/plot-cycle/history-slot"
export MOCK_FAIL=publish_workyn_yunnan_airports_if_new.sh
if bash "$work/scripts/run_website_cycle.sh" >> "$work/log"; then exit 1; fi
[[ "$(cat "$work/state/plot-cycle/history-slot")" == '0 1' ]]
unset MOCK_FAIL
: > "$work/calls"
bash "$work/scripts/run_website_cycle.sh" --service xinjiang >> "$work/log"
[[ "$(wc -l < "$work/calls" | tr -d ' ')" == 1 ]]
grep -q '^audit_iap_forecast_publication.sh|--service xinjiang|1|1$' "$work/calls"
# Drain upstream output rather than causing SIGPIPE with an early-closing head.
first="$(awk 'BEGIN {for(i=1;i<=100000;i++) print i}' | sed -n '1p')"
[[ "$first" == 1 ]]
! grep -q 'head -n' "$tools/audit_iap_forecast_publication.sh"
printf 'PASS: latest-only, deferred rotating history, NC priority, failure isolation, draining pipelines\n'
