#!/usr/bin/env bash

# Render WORK_nx to a Yunnan airport T13-T48 6x6 product, upload images to OSS,
# then publish only the JSON catalog to GitHub Pages.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDERER="${RENDERER:-$SCRIPT_DIR/render_worknx_yunnan_airports_overview.sh}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$SCRIPT_DIR/worknx_yunnan_airports_overview}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"
GITHUB_HOST="${GITHUB_HOST:-server02}"
GIT_URL="${GIT_URL:-git@github.com:keruicode/iaplacs-site.git}"
REMOTE_SITE_REPO="${REMOTE_SITE_REPO:-}"
GITHUB_KEY="${GITHUB_KEY:-/data1/elpt_2022_00083/kerui/.ssh/id_ed25519_iaplacs}"
GIT_USER_NAME="${GIT_USER_NAME:-IAP-LACS Publisher}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-publisher@iaplacs.xyz}"
IAPLACS_ASSET_FORCE_UPLOAD="${IAPLACS_ASSET_FORCE_UPLOAD:-1}"

mkdir -p "$LOG_DIR"

usage() {
  cat <<'EOF'
Usage: publish_worknx_yunnan_airports_to_github.sh [--latest | --recent COUNT]

Renders Yunnan airport T13-T48 regional 6x6 products, uploads PNG/WebP/preview
assets to OSS, and commits only data/current/forecast-runs.json to GitHub.
EOF
}

mode="--latest"
count=1
if [[ "${1:-}" == "--recent" ]]; then
  mode="--recent"
  count="${2:-5}"
elif [[ -n "${1:-}" && "${1:-}" != "--latest" ]]; then
  usage >&2
  exit 64
fi

if ! [[ "$count" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: recent count must be a positive integer" >&2
  exit 64
fi
if [[ ! -x "$RENDERER" ]]; then
  echo "ERROR: renderer is not executable: $RENDERER" >&2
  exit 1
fi

if command -v magick >/dev/null 2>&1; then
  IMAGE_TOOL=(magick)
elif command -v convert >/dev/null 2>&1; then
  IMAGE_TOOL=(convert)
else
  echo "ERROR: ImageMagick magick or convert is required" >&2
  exit 127
fi

make_webp() {
  local source="$1" output="${source%.png}.webp"
  if [[ "${IAPLACS_WEBP_FORCE:-0}" != "1" && -f "$output" && ! "$source" -nt "$output" ]]; then
    return
  fi
  "${IMAGE_TOOL[@]}" "$source" \
    -resize "3200x3200>" \
    -strip \
    -quality 92 \
    -define webp:method=6 \
    -define webp:use-sharp-yuv=true \
    "$output"
  touch -r "$source" "$output"
}

make_preview_webp() {
  local source="$1" output="${source%.png}.preview.webp"
  if [[ "${IAPLACS_PREVIEW_FORCE:-0}" != "1" && -f "$output" && ! "$source" -nt "$output" ]]; then
    return
  fi
  "${IMAGE_TOOL[@]}" "$source" \
    -resize "1100x1100>" \
    -strip \
    -quality 70 \
    -define webp:method=6 \
    -define webp:use-sharp-yuv=true \
    "$output"
  if [[ "${IAPLACS_PREVIEW_FORCE:-0}" == "1" ]]; then
    touch "$output"
  else
    touch -r "$source" "$output"
  fi
}

if [[ "$mode" == "--recent" ]]; then
  "$RENDERER" --recent "$count"
else
  "$RENDERER" --latest
fi

mapfile -t sources < <(
  find "$OUTPUT_ROOT" -mindepth 2 -maxdepth 2 -type f \
    -name 'Precip_hourly_WRF_YunnanAirports_T13_T48_InitUTC_*_combined_overview_6x6_grid.png' \
    -printf '%T@ %p\n' \
    | sort -nr \
    | head -n "$count" \
    | cut -d' ' -f2-
)

if [[ "${#sources[@]}" -ne "$count" ]]; then
  echo "ERROR: expected $count Yunnan airport overview image(s), found ${#sources[@]}" >&2
  exit 1
fi

for source in "${sources[@]}"; do
  run_prefix="$(basename "$(dirname "$source")")"
  if [[ ! "$run_prefix" =~ ^[0-9]{8}_[0-9]{2}$ ]]; then
    echo "ERROR: invalid run prefix for $source" >&2
    exit 1
  fi

  make_webp "$source"
  make_preview_webp "$source"
  base="$(basename "$source")"
  webp_base="${base%.png}.webp"
  preview_base="${base%.png}.preview.webp"
  run_dir="$(dirname "$source")"

  for required in "$run_dir/$webp_base" "$run_dir/$preview_base" "$run_dir/manifest_fragment.json" "$run_dir/airport_precip_totals.json"; do
    if [[ ! -f "$required" ]]; then
      echo "ERROR: missing required publish file: $required" >&2
      exit 1
    fi
  done

  echo "Publishing Yunnan airport regional overview: $source"
  ssh "$GITHUB_HOST" "mkdir -p ~/incoming/airport_yunnan_${run_prefix}"
  rsync -av \
    "$source" \
    "$run_dir/$webp_base" \
    "$run_dir/$preview_base" \
    "$run_dir/manifest_fragment.json" \
    "$run_dir/airport_precip_totals.json" \
    "$GITHUB_HOST:~/incoming/airport_yunnan_${run_prefix}/"

  remote_env_cmd=$(
    printf 'RUN_PREFIX=%q GIT_URL=%q REMOTE_SITE_REPO=%q GITHUB_KEY=%q GIT_USER_NAME=%q GIT_USER_EMAIL=%q IAPLACS_ASSET_FORCE_UPLOAD=%q bash -s' \
      "$run_prefix" "$GIT_URL" "$REMOTE_SITE_REPO" "$GITHUB_KEY" "$GIT_USER_NAME" "$GIT_USER_EMAIL" "$IAPLACS_ASSET_FORCE_UPLOAD"
  )

  ssh "$GITHUB_HOST" "$remote_env_cmd" <<'REMOTE'
set -Eeuo pipefail

unset LD_LIBRARY_PATH LIBRARY_PATH

IAPLACS_OSS_ENV_FILE="${IAPLACS_OSS_ENV_FILE:-$HOME/.iaplacs-oss.env}"
if [ -r "$IAPLACS_OSS_ENV_FILE" ]; then
  set -a
  . "$IAPLACS_OSS_ENV_FILE"
  set +a
fi

: "${RUN_PREFIX:?missing RUN_PREFIX}"
: "${GIT_URL:?missing GIT_URL}"
: "${GITHUB_KEY:?missing GITHUB_KEY}"
: "${GIT_USER_NAME:?missing GIT_USER_NAME}"
: "${GIT_USER_EMAIL:?missing GIT_USER_EMAIL}"
REMOTE_SITE_REPO="${REMOTE_SITE_REPO:-}"

SITE_REPO="${REMOTE_SITE_REPO:-$HOME/iaplacs-site}"
INCOMING="$HOME/incoming/airport_yunnan_${RUN_PREFIX}"
DEST="$SITE_REPO/data/current/maps/airport_yunnan_${RUN_PREFIX}"

publish_oss_assets() {
  if [ "${IAPLACS_OSS_ENABLED:-0}" != "1" ]; then
    return
  fi

  : "${IAPLACS_OSS_BUCKET:?missing IAPLACS_OSS_BUCKET}"
  : "${IAPLACS_OSS_ENDPOINT:?missing IAPLACS_OSS_ENDPOINT}"
  : "${IAPLACS_OSS_PUBLIC_BASE_URL:?missing IAPLACS_OSS_PUBLIC_BASE_URL}"

  local ossutil_bin="${IAPLACS_OSSUTIL_BIN:-$HOME/bin/ossutil}"
  local prefix="${IAPLACS_OSS_PREFIX:-}"
  local public_root="${IAPLACS_OSS_PUBLIC_BASE_URL%/}"
  local object_acl="${IAPLACS_OSS_OBJECT_ACL:-public-read}"
  local image relative key content_type first_relative first_url

  prefix="${prefix#/}"
  prefix="${prefix%/}"
  if [ ! -x "$ossutil_bin" ]; then
    echo "ERROR: ossutil not found or not executable: $ossutil_bin" >&2
    exit 1
  fi

  if [ -n "$prefix" ]; then
    export IAPLACS_ASSET_BASE_URL="${IAPLACS_ASSET_BASE_URL:-$public_root/$prefix}"
  else
    export IAPLACS_ASSET_BASE_URL="${IAPLACS_ASSET_BASE_URL:-$public_root}"
  fi

  first_relative=""
  while IFS= read -r -d '' image; do
    relative="${image#$SITE_REPO/}"
    key="$relative"
    if [ -n "$prefix" ]; then
      key="$prefix/$relative"
    fi
    case "$image" in
      *.webp) content_type="image/webp" ;;
      *.png) content_type="image/png" ;;
      *) continue ;;
    esac
    if [ "${IAPLACS_ASSET_FORCE_UPLOAD:-0}" = "1" ]; then
      "$ossutil_bin" cp "$image" "oss://${IAPLACS_OSS_BUCKET}/$key" -f -e "$IAPLACS_OSS_ENDPOINT" \
        --meta "Cache-Control:no-cache#Content-Type:$content_type" \
        --acl "$object_acl"
    else
      "$ossutil_bin" cp "$image" "oss://${IAPLACS_OSS_BUCKET}/$key" -u -e "$IAPLACS_OSS_ENDPOINT" \
        --meta "Cache-Control:no-cache#Content-Type:$content_type" \
        --acl "$object_acl"
    fi
    if [ -z "$first_relative" ]; then
      first_relative="$relative"
    fi
  done < <(find "$DEST" -maxdepth 1 -type f \( -name '*.webp' -o -name '*.png' \) -print0)

  if [ -z "$first_relative" ]; then
    echo "ERROR: no Yunnan airport raster files found for OSS upload under $DEST" >&2
    exit 1
  fi
  first_url="${IAPLACS_ASSET_BASE_URL%/}/$first_relative"
  if ! curl -fsS --range 0-0 --max-time 30 -o /dev/null "$first_url"; then
    echo "ERROR: uploaded OSS object is not publicly readable: $first_url" >&2
    exit 1
  fi
  echo "Verified OSS image: $first_url"
}

if command -v flock >/dev/null 2>&1; then
  exec 8>"$HOME/.iaplacs-github-publish.lock"
  if ! flock -w 600 8; then
    echo "ERROR: timed out waiting for GitHub publish lock" >&2
    exit 75
  fi
fi

if [ ! -f "$GITHUB_KEY" ]; then
  echo "ERROR: GitHub SSH key not found: $GITHUB_KEY" >&2
  exit 1
fi

GIT_SSH_WRAPPER="$(mktemp /tmp/iaplacs_git_ssh.XXXXXX)"
cat > "$GIT_SSH_WRAPPER" <<EOF
#!/usr/bin/env bash
unset LD_LIBRARY_PATH LIBRARY_PATH
exec ssh -i "$GITHUB_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "\$@"
EOF
chmod 700 "$GIT_SSH_WRAPPER"
trap 'rm -f "$GIT_SSH_WRAPPER"' EXIT
export GIT_SSH="$GIT_SSH_WRAPPER"

if [ ! -d "$SITE_REPO/.git" ]; then
  git clone "$GIT_URL" "$SITE_REPO"
fi

cd "$SITE_REPO"
git pull --ff-only

mkdir -p "$DEST"
rsync -av --delete "$INCOMING/" "$DEST/"
publish_oss_assets

PYTHON_BIN="$(command -v python3 || command -v python)"
if [ "${IAPLACS_OSS_ENABLED:-0}" = "1" ]; then
  export IAPLACS_MAX_RUNS="${IAPLACS_OSS_RETAIN_RUNS:-5}"
fi

CATALOG_BUILDER="$SITE_REPO/tools/build_forecast_catalog.py"
if [ ! -f "$CATALOG_BUILDER" ]; then
  echo "ERROR: forecast catalog builder not found: $CATALOG_BUILDER" >&2
  exit 1
fi
"$PYTHON_BIN" "$CATALOG_BUILDER"

git add data/current/manifest.json data/current/forecast-runs.json
if git diff --cached --quiet; then
  echo "No Yunnan airport catalog changes to commit for $RUN_PREFIX"
  exit 0
fi

git -c user.name="$GIT_USER_NAME" -c user.email="$GIT_USER_EMAIL" commit -m "Update Yunnan airport forecast ${RUN_PREFIX}"
git push origin HEAD:main
REMOTE

  echo "Published Yunnan airport prefix: $run_prefix"
done
