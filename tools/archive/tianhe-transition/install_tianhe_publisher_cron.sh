#!/usr/bin/env bash

# Run on Tianhe after the site repository has been cloned there.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBLISHER="${PUBLISHER:-$SCRIPT_DIR/tianhe_publish_forecast_to_github.sh}"
STATE_DIR="${IAPLACS_TIANHE_STATE_DIR:-$HOME/.iaplacs-tianhe}"
LOG_DIR="${IAPLACS_TIANHE_LOG_DIR:-$STATE_DIR/logs}"
DELETE_COMPLETED_MODEL_RUNS="${IAPLACS_TIANHE_DELETE_COMPLETED_MODEL_RUNS:-0}"

[[ -x "$PUBLISHER" ]] || {
  echo "ERROR: Tianhe publisher is not executable: $PUBLISHER" >&2
  exit 1
}
[[ "$DELETE_COMPLETED_MODEL_RUNS" == "0" || "$DELETE_COMPLETED_MODEL_RUNS" == "1" ]] || {
  echo "ERROR: IAPLACS_TIANHE_DELETE_COMPLETED_MODEL_RUNS must be 0 or 1" >&2
  exit 1
}

mkdir -p "$STATE_DIR" "$LOG_DIR"
STAMP="$(date +%Y%m%d_%H%M%S)"
CRON_BACKUP="$STATE_DIR/crontab-before-tianhe-publisher-${STAMP}.txt"
CRON_TMP="$(mktemp "$STATE_DIR/.crontab.XXXXXXXX")"
trap 'rm -f "$CRON_TMP"' EXIT

if crontab -l > "$CRON_BACKUP" 2>/dev/null; then
  :
else
  : > "$CRON_BACKUP"
fi

awk '
  $0 == "# IAPLACS Tianhe GitHub publisher begin" { skip = 1; next }
  $0 == "# IAPLACS Tianhe GitHub publisher end" { skip = 0; next }
  !skip { print }
' "$CRON_BACKUP" > "$CRON_TMP"

cat >> "$CRON_TMP" <<EOF

# IAPLACS Tianhe GitHub publisher begin
7,22,37,52 * * * * IAPLACS_TIANHE_DELETE_COMPLETED_MODEL_RUNS=$DELETE_COMPLETED_MODEL_RUNS $PUBLISHER >> $LOG_DIR/github-publisher.log 2>&1
# IAPLACS Tianhe GitHub publisher end
EOF

crontab "$CRON_TMP"
echo "CRONTAB_BACKUP=$CRON_BACKUP"
crontab -l
