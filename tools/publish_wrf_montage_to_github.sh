#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PNG_DIR="${PNG_DIR:-$SCRIPT_DIR/wrf_hourly_png}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"
GITHUB_HOST="${GITHUB_HOST:-server02}"
GIT_URL="${GIT_URL:-git@github.com:keruicode/iaplacs-site.git}"
REMOTE_SITE_REPO="${REMOTE_SITE_REPO:-}"
GITHUB_KEY="${GITHUB_KEY:-/public/home/elzd_2023_00026/.ssh/id_ed25519_iaplacs_github}"
GIT_USER_NAME="${GIT_USER_NAME:-IAP-LACS Publisher}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-publisher@iaplacs.xyz}"

mkdir -p "$LOG_DIR"

make_webp() {
	local source="$1"
	local max_size="$2"
	local output="${source%.png}.webp"

	if [ "${IAPLACS_WEBP_FORCE:-0}" != "1" ] && [ -f "$output" ] && [ ! "$source" -nt "$output" ]; then
		return
	fi

	local python_bin
	python_bin="$(command -v python3 || command -v python)"
	"$python_bin" - "$source" "$output" "$max_size" <<'PY'
import sys
from PIL import Image

source, output, max_size = sys.argv[1], sys.argv[2], int(sys.argv[3])
with Image.open(source) as image:
    image.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
    image.save(output, "WEBP", quality=95, method=6)
PY
	touch -r "$source" "$output"
}

make_preview_webp() {
	local source="$1"
	local output="${source%.png}.preview.webp"

	if [ "${IAPLACS_PREVIEW_FORCE:-0}" != "1" ] && [ -f "$output" ] && [ ! "$source" -nt "$output" ]; then
		return
	fi

	local python_bin
	python_bin="$(command -v python3 || command -v python)"
	"$python_bin" - "$source" "$output" <<'PY'
import sys
from PIL import Image

source, output = sys.argv[1], sys.argv[2]
with Image.open(source) as image:
    image.thumbnail((2400, 2400), Image.Resampling.LANCZOS)
    image.save(output, "WEBP", quality=85, method=6)
PY
	if [ "${IAPLACS_PREVIEW_FORCE:-0}" = "1" ]; then
		touch "$output"
	else
		touch -r "$source" "$output"
	fi
}

if [ "${1:-}" = "--all-current" ]; then
	PREFIX_FILE="${PREFIX_FILE:-$SCRIPT_DIR/latest_wrf_prefixes.txt}"
	PREFIXES=()
	if [ -s "$PREFIX_FILE" ]; then
		mapfile -t PREFIXES < <(sed '/^[[:space:]]*$/d' "$PREFIX_FILE" | sort -u)
	else
		mapfile -t PREFIXES < <(
			for overview in "$PNG_DIR"/*_combined_overview_*_grid.png; do
				[ -e "$overview" ] || continue
				basename "$overview" | sed -E 's/_combined_overview_.*_grid\.png$//'
			done | sort -u
		)
	fi

	if [ "${#PREFIXES[@]}" -eq 0 ]; then
		echo "ERROR: no WRF montage prefixes found to publish" >&2
		exit 1
	fi

	for prefix in "${PREFIXES[@]}"; do
		if [[ ! "$prefix" =~ ^[0-9]{8}_[0-9]{2}$ ]]; then
			echo "WARNING: skipping invalid montage prefix: $prefix" >&2
			continue
		fi
		if ! compgen -G "$PNG_DIR/${prefix}_combined_overview_*_grid.png" >/dev/null; then
			echo "WARNING: skipping WRF prefix without an overview: $prefix" >&2
			continue
		fi
		"$0" "$prefix"
	done
	exit 0
fi

RUN_PREFIX="${1:-}"
if [ -z "$RUN_PREFIX" ]; then
		LATEST_OVERVIEW="$(ls -t "$PNG_DIR"/*_combined_overview_*_grid.png 2>/dev/null | head -n 1 || true)"
	if [ -z "$LATEST_OVERVIEW" ]; then
		echo "ERROR: no overview montage found in $PNG_DIR" >&2
		exit 1
	fi
	RUN_PREFIX="$(basename "$LATEST_OVERVIEW" | sed -E 's/_combined_overview_.*_grid\.png$//')"
fi

if ! compgen -G "$PNG_DIR/${RUN_PREFIX}_combined_overview_*_grid.png" >/dev/null; then
	echo "ERROR: no overview found for prefix $RUN_PREFIX" >&2
	exit 1
fi

shopt -s nullglob
PNG_FILES=("$PNG_DIR/${RUN_PREFIX}"_combined_*_grid.png)
shopt -u nullglob

if [ "${#PNG_FILES[@]}" -eq 0 ]; then
	echo "ERROR: no montage PNG files found for prefix $RUN_PREFIX in $PNG_DIR" >&2
	exit 1
fi

WEBP_FILES=()
PREVIEW_FILES=()
for png in "${PNG_FILES[@]}"; do
	max_size=4800
	if [[ "$(basename "$png")" == *"_combined_overview_"* ]]; then
		max_size=6000
	fi
	make_webp "$png" "$max_size"
	make_preview_webp "$png"
	WEBP_FILES+=("${png%.png}.webp")
	PREVIEW_FILES+=("${png%.png}.preview.webp")
done
FILES=("${PNG_FILES[@]}" "${WEBP_FILES[@]}" "${PREVIEW_FILES[@]}")

echo "Publishing WRF montage prefix: $RUN_PREFIX"
printf '  %s\n' "${FILES[@]}"

ssh "$GITHUB_HOST" "rm -rf ~/incoming/wrf_montage_${RUN_PREFIX} && mkdir -p ~/incoming/wrf_montage_${RUN_PREFIX}"
rsync -av "${FILES[@]}" "$GITHUB_HOST:~/incoming/wrf_montage_${RUN_PREFIX}/"

remote_env_cmd=$(
	printf 'RUN_PREFIX=%q GIT_URL=%q REMOTE_SITE_REPO=%q GITHUB_KEY=%q GIT_USER_NAME=%q GIT_USER_EMAIL=%q bash -s' \
		"$RUN_PREFIX" "$GIT_URL" "$REMOTE_SITE_REPO" "$GITHUB_KEY" "$GIT_USER_NAME" "$GIT_USER_EMAIL"
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
INCOMING="$HOME/incoming/wrf_montage_${RUN_PREFIX}"
DEST="$SITE_REPO/data/current/maps/wrf_montage_${RUN_PREFIX}"

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
	local retain_runs="${IAPLACS_OSS_RETAIN_RUNS:-5}"
	local maps_dir="$SITE_REPO/data/current/maps"
	local image relative key content_type first_relative first_url run_dir family

	prefix="${prefix#/}"
	prefix="${prefix%/}"
	if [ ! -x "$ossutil_bin" ]; then
		echo "ERROR: ossutil not found or not executable: $ossutil_bin" >&2
		exit 1
	fi
	if [[ ! "$retain_runs" =~ ^[1-9][0-9]*$ ]]; then
		echo "ERROR: IAPLACS_OSS_RETAIN_RUNS must be a positive integer" >&2
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
		"$ossutil_bin" cp "$image" "oss://${IAPLACS_OSS_BUCKET}/$key" -f -e "$IAPLACS_OSS_ENDPOINT" \
			--meta "Cache-Control:public,max-age=604800#Content-Type:$content_type" \
			--acl "$object_acl"
		if [ -z "$first_relative" ]; then
			first_relative="$relative"
		fi
	done < <(
		while IFS= read -r run_dir; do
			find "$maps_dir/$run_dir" -type f \( -name '*.webp' -o -name '*.png' \) -print0
		done < <(
			for family in worknx_summary wrf_montage airport_yunnan; do
				find "$maps_dir" -mindepth 1 -maxdepth 1 -type d -name "${family}_????????_??" -printf '%f\n' \
					| sed -n -E "/^${family}_[0-9]{8}_[0-9]{2}$/p" \
					| sort -r | awk -v limit="$retain_runs" 'NR <= limit'
			done
		)
	)

	if [ -z "$first_relative" ]; then
		echo "ERROR: no forecast raster files found for OSS upload under $maps_dir" >&2
		exit 1
	fi
	first_url="${IAPLACS_ASSET_BASE_URL%/}/$first_relative"
	if ! curl -fsS --range 0-0 --max-time 30 -o /dev/null "$first_url"; then
		echo "ERROR: uploaded OSS object is not publicly readable: $first_url" >&2
		exit 1
	fi
	echo "Verified OSS image: $first_url"
}

prune_oss_assets() {
	if [ "${IAPLACS_OSS_ENABLED:-0}" != "1" ]; then
		return
	fi
	local prune_script="${IAPLACS_OSS_PRUNE_SCRIPT:-$HOME/bin/prune_iaplacs_oss.sh}"
	if [ ! -x "$prune_script" ]; then
		echo "ERROR: OSS retention script not found or not executable: $prune_script" >&2
		exit 1
	fi
	if [ "${IAPLACS_OSS_RETENTION_ENABLED:-0}" = "1" ]; then
		"$prune_script" --apply
	else
		"$prune_script" --dry-run
	fi
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
git pull --rebase

mkdir -p "$DEST"
rsync -av --delete "$INCOMING/" "$DEST/"
publish_oss_assets

CATALOG_BUILDER="$SITE_REPO/tools/build_forecast_catalog.py"
if [ ! -f "$CATALOG_BUILDER" ]; then
	echo "ERROR: forecast catalog builder not found: $CATALOG_BUILDER" >&2
	exit 1
fi
PYTHON_BIN="$(command -v python3 || command -v python)"
if [ "${IAPLACS_OSS_ENABLED:-0}" = "1" ]; then
	export IAPLACS_MAX_RUNS="${IAPLACS_OSS_RETAIN_RUNS:-5}"
fi
"$PYTHON_BIN" "$CATALOG_BUILDER"

git add data/current/forecast-runs.json
if git diff --cached --quiet; then
	echo "No montage changes to commit for $RUN_PREFIX"
	prune_oss_assets
	exit 0
fi

git -c user.name="$GIT_USER_NAME" -c user.email="$GIT_USER_EMAIL" commit -m "Update WRF montage ${RUN_PREFIX}"
git push origin HEAD:main
prune_oss_assets
REMOTE

echo "Published WRF montage prefix: $RUN_PREFIX"
