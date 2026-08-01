#!/usr/bin/env bash

# Publish regional and national hourly precipitation panels to OSS, then attach
# them to an existing forecast catalog run without committing raster files.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_HOST="${GITHUB_HOST:-server02}"
GIT_URL="${GIT_URL:-git@github.com:keruicode/iaplacs-site.git}"
REMOTE_SITE_REPO="${REMOTE_SITE_REPO:-}"
GITHUB_KEY="${GITHUB_KEY:-/public/home/elzd_2023_00026/.ssh/id_ed25519_iaplacs_github}"
GIT_USER_NAME="${GIT_USER_NAME:-IAP-LACS Publisher}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-publisher@iaplacs.xyz}"
PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || command -v python)}"

usage() {
  cat <<'EOF'
Usage: publish_hourly_panels_to_oss.sh \
  --family worknx_summary|wrf_montage \
  --run-prefix YYYYMMDD_HH \
  --regional-dir DIR --national-dir DIR
EOF
}

family=""
run_prefix=""
regional_dir=""
national_dir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --family) family="${2:-}"; shift 2 ;;
    --run-prefix) run_prefix="${2:-}"; shift 2 ;;
    --regional-dir) regional_dir="${2:-}"; shift 2 ;;
    --national-dir) national_dir="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; echo "ERROR: unknown argument: $1" >&2; exit 64 ;;
  esac
done

case "$family" in
  worknx_summary)
    regional_id="ningxia_region"
    national_id="worknx_national"
    ;;
  wrf_montage)
    regional_id="shangrao_region"
    national_id="shangrao_national"
    ;;
  *) usage >&2; echo "ERROR: unsupported family: $family" >&2; exit 64 ;;
esac
[[ "$run_prefix" =~ ^[0-9]{8}_[0-9]{2}$ ]] || { echo "ERROR: invalid run prefix" >&2; exit 64; }
[[ -d "$regional_dir" ]] || { echo "ERROR: regional panel directory not found: $regional_dir" >&2; exit 1; }
[[ -d "$national_dir" ]] || { echo "ERROR: national panel directory not found: $national_dir" >&2; exit 1; }

stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/iaplacs-hourly-panels.XXXXXX")"
trap 'rm -rf -- "$stage_dir"' EXIT

convert_panels() {
  local source_dir="$1" frame_id="$2" count=0 source name start end output
  while IFS= read -r -d '' source; do
    name="$(basename "$source")"
    if [[ ! "$name" =~ _rain_hour_([0-9]{10})-([0-9]{10})_BJT\.png$ ]]; then
      continue
    fi
    start="${BASH_REMATCH[1]}"
    end="${BASH_REMATCH[2]}"
    output="$stage_dir/${run_prefix}_${frame_id}_rain_hour_${start}-${end}_BJT.webp"
    "$PYTHON_BIN" - "$source" "$output" <<'PY'
import sys
from PIL import Image

source, output = sys.argv[1:3]
with Image.open(source) as image:
    image = image.convert("RGB")
    image.save(output, "WEBP", quality=92, method=6)
PY
    touch -r "$source" "$output"
    count=$((count + 1))
  done < <(find "$source_dir" -maxdepth 1 -type f -name '*_rain_hour_*_BJT.png' -print0 | sort -z)
  (( count > 0 )) || { echo "ERROR: no hourly panels found in $source_dir" >&2; exit 1; }
  echo "Prepared $count panel(s) for $frame_id"
}

convert_panels "$regional_dir" "$regional_id"
convert_panels "$national_dir" "$national_id"

incoming="hourly_panels_${family}_${run_prefix}"
ssh "$GITHUB_HOST" "rm -rf ~/incoming/$incoming && mkdir -p ~/incoming/$incoming"
rsync -av "$stage_dir/" "$GITHUB_HOST:~/incoming/$incoming/"

remote_env_cmd=$(
  printf 'FAMILY=%q RUN_PREFIX=%q INCOMING_NAME=%q GIT_URL=%q REMOTE_SITE_REPO=%q GITHUB_KEY=%q GIT_USER_NAME=%q GIT_USER_EMAIL=%q bash -s' \
    "$family" "$run_prefix" "$incoming" "$GIT_URL" "$REMOTE_SITE_REPO" "$GITHUB_KEY" "$GIT_USER_NAME" "$GIT_USER_EMAIL"
)

ssh "$GITHUB_HOST" "$remote_env_cmd" <<'REMOTE'
set -Eeuo pipefail

unset LD_LIBRARY_PATH LIBRARY_PATH
IAPLACS_OSS_ENV_FILE="${IAPLACS_OSS_ENV_FILE:-$HOME/.iaplacs-oss.env}"
if [[ -r "$IAPLACS_OSS_ENV_FILE" ]]; then
  set -a
  . "$IAPLACS_OSS_ENV_FILE"
  set +a
fi

: "${FAMILY:?missing FAMILY}"
: "${RUN_PREFIX:?missing RUN_PREFIX}"
: "${GITHUB_KEY:?missing GITHUB_KEY}"
: "${IAPLACS_OSS_BUCKET:?missing IAPLACS_OSS_BUCKET}"
: "${IAPLACS_OSS_ENDPOINT:?missing IAPLACS_OSS_ENDPOINT}"
: "${IAPLACS_OSS_PUBLIC_BASE_URL:?missing IAPLACS_OSS_PUBLIC_BASE_URL}"
[[ "${IAPLACS_OSS_ENABLED:-0}" == "1" ]] || { echo "ERROR: OSS publishing is disabled" >&2; exit 1; }

SITE_REPO="${REMOTE_SITE_REPO:-$HOME/iaplacs-site}"
INCOMING="$HOME/incoming/$INCOMING_NAME"
DEST="$SITE_REPO/data/current/maps/${FAMILY}_${RUN_PREFIX}"
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
  rm -rf -- "$INCOMING"
  find "$DEST" -maxdepth 1 -type f -name "${RUN_PREFIX}_*_rain_hour_*_BJT.webp" -delete 2>/dev/null || true
  rmdir "$DEST" 2>/dev/null || true
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
unset LD_LIBRARY_PATH LIBRARY_PATH
exec ssh -i "$GITHUB_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "\$@"
EOF
chmod 700 "$GIT_SSH_WRAPPER"
export GIT_SSH="$GIT_SSH_WRAPPER"

if [[ ! -d "$SITE_REPO/.git" ]]; then
  git clone "$GIT_URL" "$SITE_REPO"
fi
git -C "$SITE_REPO" pull --rebase
mkdir -p "$DEST"
rsync -av "$INCOMING/" "$DEST/"

while IFS= read -r -d '' image; do
  relative="${image#$SITE_REPO/}"
  key="$relative"
  [[ -z "$PREFIX" ]] || key="$PREFIX/$relative"
  "$OSSUTIL_BIN" cp "$image" "oss://${IAPLACS_OSS_BUCKET}/$key" -f -e "$IAPLACS_OSS_ENDPOINT" \
    --meta 'Cache-Control:public,max-age=604800#Content-Type:image/webp' \
    --acl "${IAPLACS_OSS_OBJECT_ACL:-public-read}"
done < <(find "$DEST" -maxdepth 1 -type f -name "${RUN_PREFIX}_*_rain_hour_*_BJT.webp" -print0)

PYTHON_BIN="$(command -v python3 || command -v python)"
"$PYTHON_BIN" "$SITE_REPO/tools/attach_hourly_frames_to_catalog.py" \
  --catalog "$SITE_REPO/data/current/forecast-runs.json" \
  --asset-dir "$DEST" \
  --family "$FAMILY" \
  --run-prefix "$RUN_PREFIX"

git -C "$SITE_REPO" add data/current/forecast-runs.json
if git -C "$SITE_REPO" diff --cached --quiet; then
  echo "No hourly catalog changes for $FAMILY $RUN_PREFIX"
  exit 0
fi
git -C "$SITE_REPO" -c user.name="$GIT_USER_NAME" -c user.email="$GIT_USER_EMAIL" \
  commit -m "Add hourly panels for ${FAMILY} ${RUN_PREFIX}"
git -C "$SITE_REPO" push origin HEAD:main
REMOTE

echo "Published hourly panels for $family $run_prefix"
