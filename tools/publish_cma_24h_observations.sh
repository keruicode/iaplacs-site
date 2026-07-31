#!/usr/bin/env bash

# Fetch CMA 24-hour observed precipitation on server02, publish the raster
# assets to OSS, then refresh the static forecast catalog.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_HOST="${GITHUB_HOST:-server02}"
GITHUB_KEY="${GITHUB_KEY:-/public/home/elzd_2023_00026/.ssh/id_ed25519_iaplacs_github}"
GIT_URL="${GIT_URL:-git@github.com:keruicode/iaplacs-site.git}"
GIT_USER_NAME="${GIT_USER_NAME:-IAP-LACS Publisher}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-publisher@iaplacs.xyz}"
CMA_OBSERVATION_LIMIT="${CMA_OBSERVATION_LIMIT:-10}"

[[ "$CMA_OBSERVATION_LIMIT" =~ ^[1-9][0-9]*$ ]] || {
  echo "ERROR: CMA_OBSERVATION_LIMIT must be a positive integer" >&2
  exit 64
}

remote_env_cmd=$(
  printf 'GITHUB_KEY=%q GIT_URL=%q GIT_USER_NAME=%q GIT_USER_EMAIL=%q CMA_OBSERVATION_LIMIT=%q bash -s' \
    "$GITHUB_KEY" "$GIT_URL" "$GIT_USER_NAME" "$GIT_USER_EMAIL" "$CMA_OBSERVATION_LIMIT"
)

ssh "$GITHUB_HOST" "$remote_env_cmd" <<'REMOTE'
set -Eeuo pipefail

unset LD_LIBRARY_PATH LIBRARY_PATH

: "${GITHUB_KEY:?missing GITHUB_KEY}"
: "${GIT_URL:?missing GIT_URL}"
: "${GIT_USER_NAME:?missing GIT_USER_NAME}"
: "${GIT_USER_EMAIL:?missing GIT_USER_EMAIL}"
: "${CMA_OBSERVATION_LIMIT:?missing CMA_OBSERVATION_LIMIT}"

GIT_SSH_WRAPPER="$(mktemp /tmp/iaplacs-cma-git.XXXXXX)"
cat > "$GIT_SSH_WRAPPER" <<EOF
#!/usr/bin/env bash
unset LD_LIBRARY_PATH LIBRARY_PATH
exec ssh -i "$GITHUB_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "\$@"
EOF
chmod 700 "$GIT_SSH_WRAPPER"
trap 'rm -f "$GIT_SSH_WRAPPER"' EXIT
export GIT_SSH="$GIT_SSH_WRAPPER"

SITE_REPO="${REMOTE_SITE_REPO:-$HOME/iaplacs-site}"
if [[ ! -d "$SITE_REPO/.git" ]]; then
  git clone "$GIT_URL" "$SITE_REPO"
fi
cd "$SITE_REPO"
git pull --ff-only

OBSERVATION_DIR="data/current/maps/cma_24h_observation"
python3 tools/fetch_cma_24h_precipitation.py \
  --output-dir "$OBSERVATION_DIR" \
  --limit "$CMA_OBSERVATION_LIMIT"

IAPLACS_OSS_ENV_FILE="${IAPLACS_OSS_ENV_FILE:-$HOME/.iaplacs-oss.env}"
if [[ -r "$IAPLACS_OSS_ENV_FILE" ]]; then
  set -a
  . "$IAPLACS_OSS_ENV_FILE"
  set +a
fi
if [[ "${IAPLACS_OSS_ENABLED:-0}" == "1" ]]; then
  : "${IAPLACS_OSS_BUCKET:?missing IAPLACS_OSS_BUCKET}"
  : "${IAPLACS_OSS_ENDPOINT:?missing IAPLACS_OSS_ENDPOINT}"
  : "${IAPLACS_OSS_PUBLIC_BASE_URL:?missing IAPLACS_OSS_PUBLIC_BASE_URL}"
  ossutil_bin="${IAPLACS_OSSUTIL_BIN:-$HOME/bin/ossutil}"
  prefix="${IAPLACS_OSS_PREFIX#/}"
  prefix="${prefix%/}"
  for image in "$OBSERVATION_DIR"/*.[Jj][Pp][Gg] "$OBSERVATION_DIR"/*.[Jj][Pp][Ee][Gg]; do
    [[ -f "$image" ]] || continue
    relative="${image#$SITE_REPO/}"
    key="$relative"
    [[ -z "$prefix" ]] || key="$prefix/$relative"
    "$ossutil_bin" cp "$image" "oss://${IAPLACS_OSS_BUCKET}/$key" -f \
      -e "$IAPLACS_OSS_ENDPOINT" \
      --meta 'Cache-Control:no-cache#Content-Type:image/jpeg' \
      --acl "${IAPLACS_OSS_OBJECT_ACL:-public-read}"
  done
  if [[ -n "$prefix" ]]; then
    export IAPLACS_ASSET_BASE_URL="${IAPLACS_OSS_PUBLIC_BASE_URL%/}/$prefix"
  else
    export IAPLACS_ASSET_BASE_URL="${IAPLACS_OSS_PUBLIC_BASE_URL%/}"
  fi
fi

python3 tools/build_forecast_catalog.py
git add data/current/forecast-runs.json
if ! git diff --cached --quiet; then
  git -c user.name="$GIT_USER_NAME" -c user.email="$GIT_USER_EMAIL" \
    commit -m 'Update CMA 24-hour precipitation observations'
  git push origin HEAD:main
fi
REMOTE

echo "Published CMA 24-hour precipitation observations."
