#!/usr/bin/env bash

# Install only the managed daily OSS retention entry in the IAP user crontab.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="${IAPLACS_RUNTIME_DIR:-$SCRIPT_DIR}"
RUNNER="$RUNTIME_DIR/run_iap_oss_retention.sh"
LOG_DIR="$RUNTIME_DIR/logs"
ARCHIVE_DIR="$RUNTIME_DIR/crontab_archive"
START="# IAPLACS OSS retention begin"
END="# IAPLACS OSS retention end"

[[ -x "$RUNNER" ]] || {
  echo "ERROR: OSS retention runner is not executable: $RUNNER" >&2
  exit 1
}

mkdir -p "$LOG_DIR" "$ARCHIVE_DIR"
stamp="$(date +%Y%m%d_%H%M%S)"
backup="$ARCHIVE_DIR/crontab-before-oss-retention-$stamp.txt"
temporary="$(mktemp "$ARCHIVE_DIR/.crontab.XXXXXXXX")"
trap 'rm -f "$temporary"' EXIT

crontab -l > "$backup" 2>/dev/null || : > "$backup"
awk -v start="$START" -v end="$END" '
  $0 == start { managed = 1; next }
  $0 == end { managed = 0; next }
  managed { next }
  /run_iap_oss_retention\.sh/ { next }
  { print }
' "$backup" > "$temporary"

cat >> "$temporary" <<EOF

$START
45 4 * * * $RUNNER >> $LOG_DIR/oss-retention.log 2>&1
$END
EOF

crontab "$temporary"
echo "Installed IAP OSS retention cron: daily at 04:45"
echo "CRONTAB_BACKUP=$backup"
