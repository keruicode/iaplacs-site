#!/usr/bin/env bash

# Upload one run's airport aviation diagnostics to OSS and rebuild the catalog.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_HOST="${GITHUB_HOST:-server02}"
GIT_URL="${GIT_URL:-git@github.com:keruicode/iaplacs-site.git}"
REMOTE_SITE_REPO="${REMOTE_SITE_REPO:-}"
GITHUB_KEY="${GITHUB_KEY:-$HOME/.iaplacs/ssh-state/id_ed25519_iaplacs_github}"
GIT_USER_NAME="${GIT_USER_NAME:-IAP-LACS Publisher}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-publisher@iaplacs.xyz}"
PYTHON_BIN="${PYTHON_BIN:-/public/software/apps/conda/latest/bin/python3}"

family=""
run_prefix=""
aviation_dir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --family) family="${2:-}"; shift 2 ;;
    --run-prefix) run_prefix="${2:-}"; shift 2 ;;
    --aviation-dir) aviation_dir="${2:-}"; shift 2 ;;
    *) echo "ERROR: unsupported argument: $1" >&2; exit 64 ;;
  esac
done

[[ "$family" == "workxj_summary" ]] || {
  echo "ERROR: airport aviation publication currently supports workxj_summary" >&2
  exit 64
}
[[ "$run_prefix" =~ ^[0-9]{8}_[0-9]{2}$ ]] || {
  echo "ERROR: run prefix must use YYYYMMDD_HH" >&2
  exit 64
}
[[ -d "$aviation_dir" ]] || {
  echo "ERROR: aviation directory not found: $aviation_dir" >&2
  exit 1
}
[[ -f "$aviation_dir/production_manifest.json" ]] || {
  echo "ERROR: aviation production manifest not found: $aviation_dir/production_manifest.json" >&2
  exit 1
}
[[ -x "$PYTHON_BIN" ]] || {
  echo "ERROR: Python is required for aviation WebP conversion: $PYTHON_BIN" >&2
  exit 127
}

make_webp() {
  local source="$1" output="${source%.png}.webp"
  "$PYTHON_BIN" - "$source" "$output" <<'PY'
import sys
from PIL import Image

source, output = sys.argv[1:]
with Image.open(source) as image:
    image = image.convert("RGB")
    image.thumbnail((6000, 6000), Image.Resampling.LANCZOS)
    image.save(output, "WEBP", quality=95, method=6)
PY
  touch -r "$source" "$output"
}

if [[ "${AVIATION_SKIP_WEBP_CONVERSION:-0}" != "1" ]]; then
  while IFS= read -r source; do
    make_webp "$source"
  done < <(find "$aviation_dir" -type f -name '*.png' | sort)
fi

png_count="$(find "$aviation_dir" -type f -name '*.png' | wc -l | tr -d ' ')"
webp_count="$(find "$aviation_dir" -type f -name '*.webp' | wc -l | tr -d ' ')"
[[ "$png_count" -gt 0 && "$png_count" == "$webp_count" ]] || {
  echo "ERROR: aviation PNG/WebP count mismatch: png=$png_count webp=$webp_count" >&2
  exit 1
}

incoming="airport_aviation_${family}_${run_prefix}"
ssh "$GITHUB_HOST" "rm -rf ~/incoming/$incoming && mkdir -p ~/incoming/$incoming"
rsync -av --delete "$aviation_dir/" "$GITHUB_HOST:~/incoming/$incoming/"

remote_env_cmd=$(
  printf 'FAMILY=%q RUN_PREFIX=%q INCOMING_NAME=%q GIT_URL=%q REMOTE_SITE_REPO=%q GITHUB_KEY=%q GIT_USER_NAME=%q GIT_USER_EMAIL=%q bash -s' \
    "$family" "$run_prefix" "$incoming" "$GIT_URL" "$REMOTE_SITE_REPO" \
    "$GITHUB_KEY" "$GIT_USER_NAME" "$GIT_USER_EMAIL"
)

ssh "$GITHUB_HOST" "$remote_env_cmd" <<'REMOTE'
set -Eeuo pipefail

unset LD_LIBRARY_PATH LIBRARY_PATH LD_PRELOAD
IAPLACS_OSS_ENV_FILE="${IAPLACS_OSS_ENV_FILE:-$HOME/.iaplacs-oss.env}"
if [[ -r "$IAPLACS_OSS_ENV_FILE" ]]; then
  set -a
  . "$IAPLACS_OSS_ENV_FILE"
  set +a
fi

: "${FAMILY:?missing FAMILY}"
: "${RUN_PREFIX:?missing RUN_PREFIX}"
: "${INCOMING_NAME:?missing INCOMING_NAME}"
: "${GIT_URL:?missing GIT_URL}"
: "${GITHUB_KEY:?missing GITHUB_KEY}"
: "${IAPLACS_OSS_BUCKET:?missing IAPLACS_OSS_BUCKET}"
: "${IAPLACS_OSS_ENDPOINT:?missing IAPLACS_OSS_ENDPOINT}"
: "${IAPLACS_OSS_PUBLIC_BASE_URL:?missing IAPLACS_OSS_PUBLIC_BASE_URL}"
[[ "${IAPLACS_OSS_ENABLED:-0}" == "1" ]] || {
  echo "ERROR: OSS publishing is disabled" >&2
  exit 1
}

SITE_REPO="${REMOTE_SITE_REPO:-$HOME/iaplacs-site}"
INCOMING="$HOME/incoming/$INCOMING_NAME"
DEST="$SITE_REPO/data/current/maps/${FAMILY}_${RUN_PREFIX}"
AVIATION_DEST="$DEST/aviation"
OSSUTIL_BIN="${IAPLACS_OSSUTIL_BIN:-$HOME/bin/ossutil}"
PREFIX="${IAPLACS_OSS_PREFIX:-}"
PREFIX="${PREFIX#/}"
PREFIX="${PREFIX%/}"
PUBLIC_ROOT="${IAPLACS_OSS_PUBLIC_BASE_URL%/}"
if [[ -n "$PREFIX" ]]; then
  export IAPLACS_ASSET_BASE_URL="${IAPLACS_ASSET_BASE_URL:-$PUBLIC_ROOT/$PREFIX}"
else
  export IAPLACS_ASSET_BASE_URL="${IAPLACS_ASSET_BASE_URL:-$PUBLIC_ROOT}"
fi

cleanup() {
  rm -rf -- "$INCOMING" "$AVIATION_DEST"
  [[ -z "${GIT_SSH_WRAPPER:-}" ]] || rm -f -- "$GIT_SSH_WRAPPER"
}
trap cleanup EXIT

if command -v flock >/dev/null 2>&1; then
  exec 8>"$HOME/.iaplacs-github-publish.lock"
  flock -w 600 8 || { echo "ERROR: timed out waiting for publish lock" >&2; exit 75; }
fi
[[ -f "$GITHUB_KEY" ]] || { echo "ERROR: GitHub key not found: $GITHUB_KEY" >&2; exit 1; }
[[ -x "$OSSUTIL_BIN" ]] || { echo "ERROR: ossutil not found: $OSSUTIL_BIN" >&2; exit 1; }

GIT_SSH_WRAPPER="$(mktemp /tmp/iaplacs_git_ssh.XXXXXX)"
cat > "$GIT_SSH_WRAPPER" <<EOF
#!/usr/bin/env bash
unset LD_LIBRARY_PATH LIBRARY_PATH LD_PRELOAD
exec /usr/bin/ssh -i "$GITHUB_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
  -o ConnectTimeout=30 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 "\$@"
EOF
chmod 700 "$GIT_SSH_WRAPPER"
export GIT_SSH="$GIT_SSH_WRAPPER"

if [[ ! -d "$SITE_REPO/.git" ]]; then
  git clone "$GIT_URL" "$SITE_REPO"
fi
cd "$SITE_REPO"
git pull --rebase
mkdir -p "$DEST"
rsync -av --delete "$INCOMING/" "$AVIATION_DEST/"

first_relative=""
while IFS= read -r -d '' image; do
  relative="${image#$SITE_REPO/}"
  key="$relative"
  [[ -z "$PREFIX" ]] || key="$PREFIX/$relative"
  case "$image" in
    *.webp) content_type="image/webp" ;;
    *.png) content_type="image/png" ;;
    *) continue ;;
  esac
  "$OSSUTIL_BIN" cp "$image" "oss://${IAPLACS_OSS_BUCKET}/$key" -f \
    -e "$IAPLACS_OSS_ENDPOINT" \
    --meta "Cache-Control:no-cache#Content-Type:$content_type" \
    --acl "${IAPLACS_OSS_OBJECT_ACL:-public-read}"
  [[ -n "$first_relative" ]] || first_relative="$relative"
done < <(find "$AVIATION_DEST" -type f \( -name '*.webp' -o -name '*.png' \) -print0)

[[ -n "$first_relative" ]] || { echo "ERROR: no aviation rasters to upload" >&2; exit 1; }
first_url="${IAPLACS_ASSET_BASE_URL%/}/$first_relative"
curl -fsS --range 0-0 --max-time 30 -o /dev/null "$first_url"
echo "Verified OSS aviation image: $first_url"

PYTHON_BIN="$(command -v python3 || command -v python)"
"$PYTHON_BIN" "$SITE_REPO/tools/build_forecast_catalog.py"
git add data/current/forecast-runs.json
if git diff --cached --quiet; then
  echo "No aviation catalog changes for $FAMILY $RUN_PREFIX"
  exit 0
fi
git -c user.name="$GIT_USER_NAME" -c user.email="$GIT_USER_EMAIL" \
  commit -m "Add Xinjiang airport aviation ${RUN_PREFIX}"
git push origin HEAD:main
REMOTE

echo "Published airport aviation products for $family $run_prefix"
