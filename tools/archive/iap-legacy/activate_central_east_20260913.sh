#!/usr/bin/env bash

# Preserve the legacy runtime root when launched from the organized directory.
if [[ -L "$(dirname "${BASH_SOURCE[0]}")/.runtime-root" ]]; then
  exec bash "$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.runtime-root" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@"
fi
# One-time server-side release; retry safely without depending on a local Mac.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER="$SCRIPT_DIR/logs/central-east-20260913.released"
now="$(TZ=Asia/Shanghai date +%Y%m%d%H%M)"
if [[ "$now" < "202609131130" ]]; then
  echo "Waiting until 2026-09-13 11:30 BJT (now $now)"
  exit 0
fi
[[ -f "$MARKER" ]] && exit 0
[[ "${1:-}" == "--check" ]] && { echo "Release is eligible"; exit 0; }
mkdir -p "$SCRIPT_DIR/logs"
exec 9>"$SCRIPT_DIR/logs/central-east-release.lock"
flock -n 9 || exit 0
ssh -o BatchMode=yes -o ConnectTimeout=30 server02 'bash -s' <<'REMOTE'
set -Eeuo pipefail
unset LD_LIBRARY_PATH LD_PRELOAD
export PATH=/public/software/apps/conda/latest/bin:/usr/bin:/bin
export GIT_SSH="$HOME/.ssh/git-iaplacs-ssh"
exec 8>"$HOME/.iaplacs-github-publish.lock"
flock -w 600 8
cd "$HOME/iaplacs-site"
git pull --ff-only
git checkout 4d222c21 -- index.html ningxia/index.html shangrao/index.html airpots/index.html xinjiang/index.html app.js
python3 - <<'PY'
import json
from pathlib import Path
path = Path('data/current/forecast-runs.json')
catalog = json.loads(path.read_text(encoding='utf-8'))
service = catalog['services']['shangrao']
service['runs'] = []
service['latest_run'] = None
temporary = path.with_suffix('.release.tmp')
temporary.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
temporary.replace(path)
PY
git add index.html ningxia/index.html shangrao/index.html airpots/index.html xinjiang/index.html app.js data/current/forecast-runs.json
if ! git diff --cached --quiet; then
  git commit -m 'Activate China central-east service after 11:30 BJT'
fi
git push origin main
git rev-parse HEAD
REMOTE
date -Is > "$MARKER"
echo "Central-east frontend submitted; WRF publication still requires a completed run."
