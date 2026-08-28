#!/usr/bin/env bash

# Installs only the IAP-LACS SSH recovery entry in the current user's crontab.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="${IAPLACS_RUNTIME_DIR:-$SCRIPT_DIR}"
RECOVERY_SCRIPT="$RUNTIME_DIR/ensure_iaplacs_ssh_state.sh"
LOG_FILE="$RUNTIME_DIR/logs/ssh-state-recovery.log"
START="# IAPLACS SSH state recovery begin"
END="# IAPLACS SSH state recovery end"

[[ -x "$RECOVERY_SCRIPT" ]] || {
  echo "ERROR: recovery script is not executable: $RECOVERY_SCRIPT" >&2
  exit 1
}

tmp="$(mktemp "${TMPDIR:-/tmp}/iaplacs-crontab.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
crontab -l 2>/dev/null > "$tmp" || true
sed -i.bak "/^${START}$/,/^${END}$/d" "$tmp"
rm -f "${tmp}.bak"
cat >> "$tmp" <<EOF

$START
*/2 * * * * $RECOVERY_SCRIPT >> $LOG_FILE 2>&1
$END
EOF
crontab "$tmp"
echo "Installed IAP-LACS SSH recovery cron: every 2 minutes"
