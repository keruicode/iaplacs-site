#!/usr/bin/env bash

# Keep IAP-LACS automation keys outside ~/.ssh.  Some login/key-download
# workflows recreate ~/.ssh, while this private state directory survives.
set -Eeuo pipefail

STATE_DIR="${IAPLACS_SSH_STATE_DIR:-$HOME/.iaplacs/ssh-state}"
SSH_DIR="$HOME/.ssh"
GITHUB_KEY_NAME="id_ed25519_iaplacs_github"
SERVER02_KEY_NAME="id_rsa"
AUTHORIZED_KEY_COMMENT="${IAPLACS_AUTHORIZED_KEY_COMMENT:-2602005529@qq.com}"
AUTHORIZED_KEY_STATE_NAME="authorized_keys.iaplacs"
BOOTSTRAP=0

if [[ "${1:-}" == "--bootstrap" ]]; then
  BOOTSTRAP=1
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--bootstrap]" >&2
  exit 64
fi

log() {
  printf '%s iaplacs-ssh-state: %s\n' "$(date '+%F %T')" "$*"
}

install -d -m 700 "$STATE_DIR" "$SSH_DIR"

bootstrap_file() {
  local name mode source target
  name="$1"
  mode="$2"
  source="$SSH_DIR/$name"
  target="$STATE_DIR/$name"
  [[ -f "$target" ]] && return 0
  [[ -f "$source" ]] || {
    echo "ERROR: cannot bootstrap missing $source" >&2
    return 1
  }
  install -m "$mode" "$source" "$target"
  log "saved canonical $name"
}

bootstrap_authorized_key() {
  local source target temporary
  source="$SSH_DIR/authorized_keys"
  target="$STATE_DIR/$AUTHORIZED_KEY_STATE_NAME"
  [[ -s "$target" ]] && return 0
  [[ -f "$source" ]] || {
    echo "ERROR: cannot bootstrap missing $source" >&2
    return 1
  }

  temporary="$(mktemp "$STATE_DIR/.authorized-key.XXXXXX")"
  if ! awk -v comment="$AUTHORIZED_KEY_COMMENT" '$3 == comment { key = $0 } END { if (key != "") print key; else exit 1 }' \
    "$source" > "$temporary"; then
    rm -f "$temporary"
    echo "ERROR: cannot find authorized key comment $AUTHORIZED_KEY_COMMENT in $source" >&2
    return 1
  fi
  chmod 600 "$temporary"
  mv "$temporary" "$target"
  log "saved canonical authorized key $AUTHORIZED_KEY_COMMENT"
}

if (( BOOTSTRAP )); then
  bootstrap_file "$SERVER02_KEY_NAME" 600
  bootstrap_file "$GITHUB_KEY_NAME" 600
  bootstrap_file "$GITHUB_KEY_NAME.pub" 644
  bootstrap_authorized_key
fi

for required in "$STATE_DIR/$SERVER02_KEY_NAME" "$STATE_DIR/$GITHUB_KEY_NAME"; do
  [[ -f "$required" ]] || {
    echo "ERROR: canonical key is missing: $required; run --bootstrap before ~/.ssh is reset" >&2
    exit 1
  }
done

# Restore only missing generic server02 key. Do not overwrite an administrator
# rotation with an older local copy.
if [[ ! -f "$SSH_DIR/$SERVER02_KEY_NAME" ]]; then
  install -m 600 "$STATE_DIR/$SERVER02_KEY_NAME" "$SSH_DIR/$SERVER02_KEY_NAME"
  log "restored missing $SERVER02_KEY_NAME"
else
  chmod 600 "$SSH_DIR/$SERVER02_KEY_NAME"
fi

# These are dedicated to IAP-LACS GitHub publishing, so canonical state wins.
install -m 600 "$STATE_DIR/$GITHUB_KEY_NAME" "$SSH_DIR/$GITHUB_KEY_NAME"
if [[ -f "$STATE_DIR/$GITHUB_KEY_NAME.pub" ]]; then
  install -m 644 "$STATE_DIR/$GITHUB_KEY_NAME.pub" "$SSH_DIR/$GITHUB_KEY_NAME.pub"
fi

cat > "$SSH_DIR/git-iaplacs-ssh" <<EOF
#!/usr/bin/env bash
unset LD_LIBRARY_PATH LIBRARY_PATH LD_PRELOAD
exec /usr/bin/ssh \\
  -i "$STATE_DIR/$GITHUB_KEY_NAME" \\
  -o IdentitiesOnly=yes \\
  -o StrictHostKeyChecking=no \\
  -o ConnectTimeout=30 \\
  -o ServerAliveInterval=30 \\
  -o ServerAliveCountMax=3 \\
  "\$@"
EOF
chmod 700 "$SSH_DIR/git-iaplacs-ssh"

# Preserve this user-managed inbound SSH authorization after a platform login
# flow recreates ~/.ssh. This only appends the exact missing line; it never
# removes or replaces other platform/user entries in authorized_keys.
AUTHORIZED_KEYS_FILE="$SSH_DIR/authorized_keys"
AUTHORIZED_KEY_STATE_FILE="$STATE_DIR/$AUTHORIZED_KEY_STATE_NAME"
[[ -s "$AUTHORIZED_KEY_STATE_FILE" ]] || {
  echo "ERROR: canonical authorized key is missing: $AUTHORIZED_KEY_STATE_FILE; run --bootstrap before ~/.ssh is reset" >&2
  exit 1
}
AUTHORIZED_KEY_LINE="$(cat "$AUTHORIZED_KEY_STATE_FILE")"
[[ -n "$AUTHORIZED_KEY_LINE" ]] || {
  echo "ERROR: canonical authorized key is empty: $AUTHORIZED_KEY_STATE_FILE" >&2
  exit 1
}
touch "$AUTHORIZED_KEYS_FILE"
chmod 600 "$AUTHORIZED_KEYS_FILE"
if ! grep -Fqx "$AUTHORIZED_KEY_LINE" "$AUTHORIZED_KEYS_FILE"; then
  printf '%s\n' "$AUTHORIZED_KEY_LINE" >> "$AUTHORIZED_KEYS_FILE"
  log "restored missing authorized key $AUTHORIZED_KEY_COMMENT"
fi
