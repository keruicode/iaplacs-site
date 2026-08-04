#!/usr/bin/env bash

# Install only the managed BJT 06 early-publication block and preserve every
# unrelated user crontab entry.
set -Eeuo pipefail

SCRIPT_PATH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_PATH_DIR/build_forecast_catalog.py" ]]; then
  SCRIPT_DIR="$SCRIPT_PATH_DIR"
else
  SCRIPT_DIR="$(cd "$SCRIPT_PATH_DIR/.." && pwd)"
fi
CRON_ARCHIVE_DIR="${CRON_ARCHIVE_DIR:-$SCRIPT_DIR/crontab_archive}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"
PUBLISH_SCRIPT="${PUBLISH_SCRIPT:-$SCRIPT_DIR/publish_bjt06_partial_forecasts.sh}"

[[ -x "$PUBLISH_SCRIPT" ]] || {
  echo "ERROR: early publication script is not executable: $PUBLISH_SCRIPT" >&2
  exit 1
}

mkdir -p "$CRON_ARCHIVE_DIR" "$LOG_DIR"
STAMP="$(date +%Y%m%d_%H%M%S)"
CRON_BACKUP="$CRON_ARCHIVE_DIR/crontab-before-bjt06-partial-${STAMP}.txt"
CRON_TMP="$(mktemp "$CRON_ARCHIVE_DIR/.crontab.XXXXXXXX")"
trap 'rm -f "$CRON_TMP"' EXIT

crontab -l > "$CRON_BACKUP" 2>/dev/null || : > "$CRON_BACKUP"
awk '
  $0 == "# IAPLACS BJT06 early publication begin" { skip = 1; next }
  $0 == "# IAPLACS BJT06 early publication end" { skip = 0; next }
  !skip { print }
' "$CRON_BACKUP" > "$CRON_TMP"

cat >> "$CRON_TMP" <<EOF

# IAPLACS BJT06 early publication begin
0,15,30,45 6,7 * * * $PUBLISH_SCRIPT >> $LOG_DIR/bjt06-partial.log 2>&1
# IAPLACS BJT06 early publication end
EOF

crontab "$CRON_TMP"
echo "CRONTAB_BACKUP=$CRON_BACKUP"
crontab -l
