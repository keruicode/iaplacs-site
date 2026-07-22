#!/usr/bin/env bash

# Install or update the managed daily IAP runtime backup cron entry.
set -Eeuo pipefail

SCRIPT_PATH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_PATH_DIR/build_forecast_catalog.py" ]]; then
  SCRIPT_DIR="$SCRIPT_PATH_DIR"
else
  SCRIPT_DIR="$(cd "$SCRIPT_PATH_DIR/.." && pwd)"
fi
CRON_ARCHIVE_DIR="${CRON_ARCHIVE_DIR:-$SCRIPT_DIR/crontab_archive}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"
BACKUP_SCRIPT="${BACKUP_SCRIPT:-$SCRIPT_DIR/backup_iap_runtime.sh}"

if [[ ! -x "$BACKUP_SCRIPT" ]]; then
  echo "ERROR: backup script is not executable: $BACKUP_SCRIPT" >&2
  exit 1
fi

mkdir -p "$CRON_ARCHIVE_DIR" "$LOG_DIR"
STAMP="$(date +%Y%m%d_%H%M%S)"
CRON_BACKUP="$CRON_ARCHIVE_DIR/crontab-before-runtime-backup-${STAMP}.txt"
CRON_TMP="$(mktemp "$CRON_ARCHIVE_DIR/.crontab.XXXXXXXX")"
trap 'rm -f "$CRON_TMP"' EXIT

if crontab -l > "$CRON_BACKUP" 2>/dev/null; then
  :
else
  : > "$CRON_BACKUP"
fi

awk '
  $0 == "# IAPLACS runtime backup begin" { skip = 1; next }
  $0 == "# IAPLACS runtime backup end" { skip = 0; next }
  !skip { print }
' "$CRON_BACKUP" > "$CRON_TMP"

cat >> "$CRON_TMP" <<EOF

# IAPLACS runtime backup begin
15 3 * * * $BACKUP_SCRIPT >> $LOG_DIR/iap-runtime-backup.log 2>&1
# IAPLACS runtime backup end
EOF

crontab "$CRON_TMP"
echo "CRONTAB_BACKUP=$CRON_BACKUP"
crontab -l
