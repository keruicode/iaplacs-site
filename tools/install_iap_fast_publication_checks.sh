#!/usr/bin/env bash

# Install frequent, overlap-safe publication checks without changing unrelated
# user cron entries.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_ROOT="${RUNTIME_ROOT:-$SCRIPT_DIR}"
if [[ ! -x "$RUNTIME_ROOT/audit_iap_forecast_publication.sh" ]]; then
  RUNTIME_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

AUDITOR="$RUNTIME_ROOT/audit_iap_forecast_publication.sh"
YUNNAN_CHECK="$RUNTIME_ROOT/publish_workyn_yunnan_airports_if_new.sh"
LOG_DIR="$RUNTIME_ROOT/logs"
ARCHIVE_DIR="$RUNTIME_ROOT/crontab_archive"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$ARCHIVE_DIR/crontab-before-fast-checks-$STAMP.txt"
CRON_TMP="$(mktemp "$ARCHIVE_DIR/.crontab.XXXXXXXX")"

cleanup() {
  rm -f -- "$CRON_TMP"
}
trap cleanup EXIT

[[ -x "$AUDITOR" ]] || {
  echo "ERROR: publication auditor is not executable: $AUDITOR" >&2
  exit 1
}
[[ -x "$YUNNAN_CHECK" ]] || {
  echo "ERROR: Yunnan check is not executable: $YUNNAN_CHECK" >&2
  exit 1
}

mkdir -p "$LOG_DIR" "$ARCHIVE_DIR"
crontab -l > "$BACKUP" 2>/dev/null || : > "$BACKUP"

awk '
  /^# IAPLACS fast publication checks begin$/ { managed=1; next }
  /^# IAPLACS fast publication checks end$/ { managed=0; next }
  managed { next }
  /audit_iap_forecast_publication\.sh/ { next }
  /publish_workyn_yunnan_airports_if_new\.sh/ { next }
  { print }
' "$BACKUP" > "$CRON_TMP"

cat >> "$CRON_TMP" <<EOF
# IAPLACS fast publication checks begin
2,12,22,32,42,52 * * * * $AUDITOR >> $LOG_DIR/publication-audit.log 2>&1
7,17,27,37,47,57 * * * * $YUNNAN_CHECK >> $LOG_DIR/yunnan-airport-publish.log 2>&1
# IAPLACS fast publication checks end
EOF

crontab "$CRON_TMP"
echo "Archived previous crontab: $BACKUP"
crontab -l
