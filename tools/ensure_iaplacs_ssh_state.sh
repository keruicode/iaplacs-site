#!/usr/bin/env bash

# Keep IAP-LACS automation keys outside ~/.ssh.  Some login/key-download
# workflows recreate ~/.ssh, while this private state directory survives.
set -Eeuo pipefail

STATE_DIR="${IAPLACS_SSH_STATE_DIR:-$HOME/.iaplacs/ssh-state}"
SSH_DIR="$HOME/.ssh"
GITHUB_KEY_NAME="id_ed25519_iaplacs_github"
SERVER02_KEY_NAME="id_rsa"
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

if (( BOOTSTRAP )); then
  bootstrap_file "$SERVER02_KEY_NAME" 600
  bootstrap_file "$GITHUB_KEY_NAME" 600
  bootstrap_file "$GITHUB_KEY_NAME.pub" 644
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
