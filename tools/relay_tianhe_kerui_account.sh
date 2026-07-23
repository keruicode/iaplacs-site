#!/usr/bin/env bash
# Migrate the Tianhe kerui runtime between accounts through the local Mac.
set -Eeuo pipefail

SOURCE_TARGET="${SOURCE_TARGET:-sunjm@192.168.4.11}"
SOURCE_ROOT="${SOURCE_ROOT:-/fs1/home/sunjm/kerui}"
TARGET_TARGET="${TARGET_TARGET:-junzhang@192.168.10.50}"
TARGET_ROOT="${TARGET_ROOT:-/fs2/home/junzhang/kerui}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-60}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

quote() {
  printf '%q' "$1"
}

[[ "$CONNECT_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || fail "CONNECT_TIMEOUT must be positive"
[[ "$SOURCE_ROOT" == /fs1/home/sunjm/kerui ]] || fail "unexpected SOURCE_ROOT: $SOURCE_ROOT"
[[ "$TARGET_ROOT" == /fs2/home/junzhang/kerui ]] || fail "unexpected TARGET_ROOT: $TARGET_ROOT"

TARGET_PARENT="$(dirname "$TARGET_ROOT")"
TRANSFER_ID="$(date +%Y%m%d_%H%M%S)_$$"
SOURCE_ARCHIVE="/tmp/iaplacs-kerui-${TRANSFER_ID}.tar.gz"
SOURCE_SHA="${SOURCE_ARCHIVE}.sha256"
TARGET_STAGE="${TARGET_PARENT}/.iaplacs-kerui-incoming-${TRANSFER_ID}"
LOCAL_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/iaplacs-kerui-account.XXXXXXXX")"
ARCHIVE_NAME="$(basename "$SOURCE_ARCHIVE")"
COMPLETED=0
TARGET_WAS_EMPTY=0

ssh_options=(-tt -o BatchMode=yes -o "ConnectTimeout=$CONNECT_TIMEOUT" -o StrictHostKeyChecking=ask)
sftp_options=(-oBatchMode=yes -o"ConnectTimeout=$CONNECT_TIMEOUT" -oStrictHostKeyChecking=ask)

cleanup() {
  local status=$?
  rm -rf "$LOCAL_STAGE"
  ssh "${ssh_options[@]}" "$SOURCE_TARGET" \
    "rm -f -- $(quote "$SOURCE_ARCHIVE") $(quote "$SOURCE_SHA")" >/dev/null 2>&1 || true
  if [[ "$COMPLETED" != "1" ]]; then
    ssh "${ssh_options[@]}" "$TARGET_TARGET" \
      "rm -rf -- $(quote "$TARGET_STAGE")" >/dev/null 2>&1 || true
  fi
  exit "$status"
}
trap cleanup EXIT

ssh "${ssh_options[@]}" "$SOURCE_TARGET" "
  set -e
  test -d $(quote "$SOURCE_ROOT")
  test -x $(quote "$SOURCE_ROOT/bin/git-system")
  test -L $(quote "$SOURCE_ROOT/iaplacs-runtime/current")
  tar -C $(quote "$(dirname "$SOURCE_ROOT")") -czf $(quote "$SOURCE_ARCHIVE") $(quote "$(basename "$SOURCE_ROOT")")
  cd /tmp
  sha256sum $(quote "$ARCHIVE_NAME") > $(quote "${ARCHIVE_NAME}.sha256")
"

printf 'get %s %s\nget %s %s\nquit\n' \
  "$SOURCE_ARCHIVE" "$LOCAL_STAGE/$ARCHIVE_NAME" \
  "$SOURCE_SHA" "$LOCAL_STAGE/${ARCHIVE_NAME}.sha256" \
  | sftp "${sftp_options[@]}" "$SOURCE_TARGET"
(cd "$LOCAL_STAGE" && sha256sum -c "${ARCHIVE_NAME}.sha256")

ssh "${ssh_options[@]}" "$TARGET_TARGET" "
  set -e
  if test -e $(quote "$TARGET_ROOT"); then
    test -d $(quote "$TARGET_ROOT")
    test -z \"\$(find $(quote "$TARGET_ROOT") -mindepth 1 -maxdepth 1 -print -quit)\"
    printf 'empty-target\n'
  else
    printf 'absent-target\n'
  fi
  mkdir -p $(quote "$TARGET_STAGE")
" | tr -d '\r' | grep -qx 'empty-target' && TARGET_WAS_EMPTY=1 || true
if [[ "$TARGET_WAS_EMPTY" != "1" ]]; then
  ssh "${ssh_options[@]}" "$TARGET_TARGET" \
    "test ! -e $(quote "$TARGET_ROOT")" || fail "target directory appeared during setup"
fi
printf 'put %s %s\nput %s %s\nquit\n' \
  "$LOCAL_STAGE/$ARCHIVE_NAME" "$TARGET_STAGE/$ARCHIVE_NAME" \
  "$LOCAL_STAGE/${ARCHIVE_NAME}.sha256" "$TARGET_STAGE/${ARCHIVE_NAME}.sha256" \
  | sftp "${sftp_options[@]}" "$TARGET_TARGET"

ssh "${ssh_options[@]}" "$TARGET_TARGET" "
  set -e
  cd $(quote "$TARGET_STAGE")
  sha256sum -c $(quote "${ARCHIVE_NAME}.sha256")
  tar -tzf $(quote "$ARCHIVE_NAME") >/dev/null
  tar --no-same-owner -xzf $(quote "$ARCHIVE_NAME")
  test -x $(quote "$TARGET_STAGE/kerui/bin/git-system")
  test -L $(quote "$TARGET_STAGE/kerui/iaplacs-runtime/current")
  test -f $(quote "$TARGET_STAGE/kerui/iaplacs-runtime/current/runtime/publish_worknx_ningxia_to_github.sh")
  if test -e $(quote "$TARGET_ROOT"); then
    test -d $(quote "$TARGET_ROOT")
    test -z \"\$(find $(quote "$TARGET_ROOT") -mindepth 1 -maxdepth 1 -print -quit)\"
    rmdir $(quote "$TARGET_ROOT")
  fi
  mv $(quote "$TARGET_STAGE/kerui") $(quote "$TARGET_ROOT")
  rm -f -- $(quote "$TARGET_STAGE/$ARCHIVE_NAME") $(quote "$TARGET_STAGE/${ARCHIVE_NAME}.sha256")
  rmdir $(quote "$TARGET_STAGE")
  du -sh $(quote "$TARGET_ROOT")
"

COMPLETED=1
echo "MIGRATED=$TARGET_TARGET:$TARGET_ROOT"
