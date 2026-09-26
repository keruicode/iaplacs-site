#!/usr/bin/env bash

# Preserve the legacy runtime root when launched from the organized directory.
if [[ -L "$(dirname "${BASH_SOURCE[0]}")/.runtime-root" ]]; then
  exec bash "$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.runtime-root" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@"
fi

set -Eeuo pipefail

WEBSITE_DIR="/data1/elpt_2022_00083/kerui/Website"

set +u
if [ -f /etc/profile ]; then
  source /etc/profile || true
fi
if [ -f "$HOME/.bashrc.minkerui" ]; then
  source "$HOME/.bashrc.minkerui" || true
fi
set -u

cd "$WEBSITE_DIR"
exec "$WEBSITE_DIR/publish_worknx_ningxia_to_github.sh" --latest
