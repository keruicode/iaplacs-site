#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

WORK_NX_ROOT="${WORK_NX_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK_nx}"
STAGE_DIR="${STAGE_DIR:-$SCRIPT_DIR/worknx_summary}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"
GITHUB_HOST="${GITHUB_HOST:-server02}"
GIT_URL="${GIT_URL:-git@github.com:keruicode/iaplacs-site.git}"
REMOTE_SITE_REPO="${REMOTE_SITE_REPO:-}"
GITHUB_KEY="${GITHUB_KEY:-/public/home/elzd_2023_00026/.ssh/id_ed25519_iaplacs_github}"
GIT_USER_NAME="${GIT_USER_NAME:-IAP-LACS Publisher}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-publisher@iaplacs.xyz}"
MIN_FILE_AGE_SECONDS="${MIN_FILE_AGE_SECONDS:-1200}"
STABILITY_SLEEP_SECONDS="${STABILITY_SLEEP_SECONDS:-5}"
SOURCE_IMAGE_GLOB="${SOURCE_IMAGE_GLOB:-Precip_hourly_WRF_AllRain_T01_T48_InitUTC_*.png}"
IAPLACS_ASSET_FORCE_UPLOAD="${IAPLACS_ASSET_FORCE_UPLOAD:-0}"
PYTHON_BIN="${PYTHON_BIN:-/public/software/apps/conda/latest/bin/python3}"
if [[ ! -x "$PYTHON_BIN" ]]; then
	PYTHON_BIN="$(command -v python3 || command -v python || true)"
fi

mkdir -p "$STAGE_DIR" "$LOG_DIR"
if [[ -z "$PYTHON_BIN" || ! -x "$PYTHON_BIN" ]]; then
	echo "ERROR: Python 3 is required for WebP conversion" >&2
	exit 127
fi

make_webp() {
	local source="$1"
	local max_size="$2"
	local output
	output="${source%.png}.webp"

	if [ "${IAPLACS_WEBP_FORCE:-0}" != "1" ] && [ -f "$output" ] && [ ! "$source" -nt "$output" ]; then
		return
	fi

	"$PYTHON_BIN" - "$source" "$output" "$max_size" <<'PY'
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
	local output
	output="${source%.png}.preview.webp"

	if [ "${IAPLACS_PREVIEW_FORCE:-0}" != "1" ] && [ -f "$output" ] && [ ! "$source" -nt "$output" ]; then
		return
	fi

	"$PYTHON_BIN" - "$source" "$output" <<'PY'
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

if [ ! -d "$WORK_NX_ROOT" ]; then
	echo "ERROR: WORK_NX_ROOT not found: $WORK_NX_ROOT" >&2
	exit 1
fi

now_epoch="$(date +%s)"
src=""
src_epoch=""

while IFS= read -r line; do
	epoch="${line%% *}"
	path="${line#* }"
	epoch_int="${epoch%.*}"
	age=$((now_epoch - epoch_int))
	if [ "$age" -lt "$MIN_FILE_AGE_SECONDS" ]; then
		echo "Skipping too-new image age=${age}s: $path"
		continue
	fi
	src="$path"
	src_epoch="$epoch_int"
	break
done < <(
	find "$WORK_NX_ROOT" -maxdepth 4 -type f \
		-name "$SOURCE_IMAGE_GLOB" \
		-printf '%T@ %p\n' 2>/dev/null | sort -nr
)

if [ -z "$src" ]; then
	echo "ERROR: no stable WORK_nx image matching $SOURCE_IMAGE_GLOB found under $WORK_NX_ROOT" >&2
	exit 1
fi

size_before="$(stat -c '%s' "$src")"
sleep "$STABILITY_SLEEP_SECONDS"
size_after="$(stat -c '%s' "$src")"
if [ "$size_before" != "$size_after" ]; then
	echo "ERROR: source image size changed during stability check: $src" >&2
	echo "before=$size_before after=$size_after" >&2
	exit 2
fi

base="$(basename "$src")"
if [[ "$base" =~ InitUTC_([0-9]{4})-([0-9]{2})-([0-9]{2})_([0-9]{2})_([0-9]{2}) ]]; then
	run_prefix="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}_${BASH_REMATCH[4]}"
	init_utc="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:00"
else
	echo "ERROR: cannot parse init time from $base" >&2
	exit 1
fi

read -r run_time_bjt valid_time_bjt < <(
	"$PYTHON_BIN" - "$init_utc" <<'PY'
from __future__ import print_function
import sys
from datetime import datetime, timedelta

dt = datetime.strptime(sys.argv[1], "%Y-%m-%d %H:%M:%S")
run = dt + timedelta(hours=8)
valid = dt + timedelta(hours=48+8)
print(run.strftime("%Y-%m-%dT%H:%M:%S+08:00"), valid.strftime("%Y-%m-%dT%H:%M:%S+08:00"))
PY
)

generated_at="$(date -d "@$src_epoch" '+%Y-%m-%dT%H:%M:%S+08:00')"
run_dir="$STAGE_DIR/$run_prefix"
mkdir -p "$run_dir"
cp -f --preserve=timestamps -- "$src" "$run_dir/$base"
make_webp "$run_dir/$base" 6000
make_preview_webp "$run_dir/$base"
webp_base="${base%.png}.webp"
preview_base="${base%.png}.preview.webp"
webp_bytes="$(stat -c '%s' "$run_dir/$webp_base")"
preview_bytes="$(stat -c '%s' "$run_dir/$preview_base")"

repo_rel_dir="data/current/maps/worknx_summary_${run_prefix}"
repo_rel_file="./${repo_rel_dir}/${base}"
repo_rel_webp_file="./${repo_rel_dir}/${webp_base}"

cat > "$run_dir/manifest_fragment.json" <<EOF
{
  "run_prefix": "${run_prefix}",
  "source_image": "${src}",
  "file": "${repo_rel_file}",
  "run_time": "${run_time_bjt}",
  "valid_time": "${valid_time_bjt}",
  "generated_at": "${generated_at}",
  "bytes": ${size_after}
}
EOF

echo "Selected WORK_nx summary image:"
echo "  source=$src"
echo "  mtime=$generated_at"
echo "  bytes=$size_after"
echo "  webp_bytes=$webp_bytes"
echo "  preview_bytes=$preview_bytes"
echo "  run_prefix=$run_prefix"

ssh "$GITHUB_HOST" "mkdir -p ~/incoming/worknx_summary_${run_prefix}"
rsync -av "$run_dir/$base" "$run_dir/$webp_base" "$run_dir/$preview_base" "$run_dir/manifest_fragment.json" "$GITHUB_HOST:~/incoming/worknx_summary_${run_prefix}/"

remote_env_cmd=$(
	printf 'RUN_PREFIX=%q BASE=%q WEBP_BASE=%q PREVIEW_BASE=%q REPO_REL_DIR=%q REPO_REL_FILE=%q REPO_REL_WEBP_FILE=%q RUN_TIME_BJT=%q VALID_TIME_BJT=%q GENERATED_AT=%q BYTES=%q WEBP_BYTES=%q GIT_URL=%q REMOTE_SITE_REPO=%q GITHUB_KEY=%q GIT_USER_NAME=%q GIT_USER_EMAIL=%q IAPLACS_ASSET_FORCE_UPLOAD=%q bash -s' \
		"$run_prefix" "$base" "$webp_base" "$preview_base" "$repo_rel_dir" "$repo_rel_file" "$repo_rel_webp_file" "$run_time_bjt" "$valid_time_bjt" "$generated_at" "$size_after" "$webp_bytes" "$GIT_URL" "$REMOTE_SITE_REPO" "$GITHUB_KEY" "$GIT_USER_NAME" "$GIT_USER_EMAIL" "$IAPLACS_ASSET_FORCE_UPLOAD"
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
: "${BASE:?missing BASE}"
: "${WEBP_BASE:?missing WEBP_BASE}"
: "${PREVIEW_BASE:?missing PREVIEW_BASE}"
: "${REPO_REL_DIR:?missing REPO_REL_DIR}"
: "${REPO_REL_FILE:?missing REPO_REL_FILE}"
: "${REPO_REL_WEBP_FILE:?missing REPO_REL_WEBP_FILE}"
: "${RUN_TIME_BJT:?missing RUN_TIME_BJT}"
: "${VALID_TIME_BJT:?missing VALID_TIME_BJT}"
: "${GENERATED_AT:?missing GENERATED_AT}"
: "${BYTES:?missing BYTES}"
: "${WEBP_BYTES:?missing WEBP_BYTES}"
: "${GIT_URL:?missing GIT_URL}"
: "${GITHUB_KEY:?missing GITHUB_KEY}"
: "${GIT_USER_NAME:?missing GIT_USER_NAME}"
: "${GIT_USER_EMAIL:?missing GIT_USER_EMAIL}"
REMOTE_SITE_REPO="${REMOTE_SITE_REPO:-}"

SITE_REPO="${REMOTE_SITE_REPO:-$HOME/iaplacs-site}"
INCOMING="$HOME/incoming/worknx_summary_${RUN_PREFIX}"
DEST="$SITE_REPO/${REPO_REL_DIR}"

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
	done < <(
		if [ "${IAPLACS_ASSET_FORCE_UPLOAD:-0}" = "1" ]; then
			find "$maps_dir/worknx_summary_${RUN_PREFIX}" -type f \( -name '*.webp' -o -name '*.png' \) -print0
		else
			while IFS= read -r run_dir; do
				find "$maps_dir/$run_dir" -type f \( -name '*.webp' -o -name '*.png' \) -print0
			done < <(
				for family in worknx_summary wrf_montage airport_yunnan; do
					find "$maps_dir" -mindepth 1 -maxdepth 1 -type d -name "${family}_????????_??" -printf '%f\n' \
						| sed -n -E "/^${family}_[0-9]{8}_[0-9]{2}$/p" \
						| sort -r | awk -v limit="$retain_runs" 'NR <= limit'
				done
			)
		fi
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
# A single run directory contains national, regional, and accumulated products.
# Preserve earlier assets from the same run while publishing the next one.
rsync -av --include="$BASE" --include="$WEBP_BASE" --include="$PREVIEW_BASE" --include="manifest_fragment.json" --exclude='*' "$INCOMING/" "$DEST/"
publish_oss_assets

PYTHON_BIN="$(command -v python3 || command -v python)"
if [ "${IAPLACS_OSS_ENABLED:-0}" = "1" ]; then
	export IAPLACS_MAX_RUNS="${IAPLACS_OSS_RETAIN_RUNS:-5}"
fi
"$PYTHON_BIN" - "$SITE_REPO/data/current/manifest.json" "$SITE_REPO/data/current/forecast-runs.json" <<'PY'
from __future__ import print_function
import json
import os
import sys
import tempfile

manifest_path = sys.argv[1]
catalog_path = sys.argv[2]
run_prefix = os.environ["RUN_PREFIX"]
repo_rel_file = os.environ["REPO_REL_FILE"]
repo_rel_webp_file = os.environ["REPO_REL_WEBP_FILE"]
run_time_bjt = os.environ["RUN_TIME_BJT"]
valid_time_bjt = os.environ["VALID_TIME_BJT"]
generated_at = os.environ["GENERATED_AT"]
bytes_size = int(os.environ["WEBP_BYTES"])
asset_base_url = os.environ.get("IAPLACS_ASSET_BASE_URL", "").rstrip("/")

def asset_url(relative):
    if not asset_base_url:
        return relative
    return asset_base_url + "/" + relative.lstrip("./")

published_file = asset_url(repo_rel_webp_file)

def atomic_write_json(path, data):
    directory = os.path.dirname(path)
    if not os.path.isdir(directory):
        os.makedirs(directory)
    fd, tmp_path = tempfile.mkstemp(prefix=os.path.basename(path) + ".", suffix=".tmp", dir=directory)
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, ensure_ascii=True, indent=2, sort_keys=False)
        f.write("\n")
    os.rename(tmp_path, path)

def label_from_iso(value):
    return value.replace("T", " ").replace("+08:00", " BJT")

def product_payload():
    return {
        "id": "worknx_summary_precip",
        "title": "WRF综合降水预报 T01-T48",
        "category": "模式预报",
        "unit": "mm",
        "color": "#087d7a",
        "description": "WORK_nx 生成的 WRF 全降水逐小时综合预报拼图，按图片文件生成时间自动选择最新稳定 T48 产品。",
        "legend": {
            "gradient": "linear-gradient(90deg, #e8f2f5, #9ad4ee, #4b93c4, #31a45f, #f2d34c, #e78935, #bd3434)",
            "ticks": ["0", "10", "25", "50", "100", "150+"]
        },
        "metrics": [
            {"label": "起报时间", "value": run_prefix},
            {"label": "生成时间", "value": label_from_iso(generated_at)},
            {"label": "图像大小", "value": "%.1f MB" % (bytes_size / 1048576.0)}
        ],
        "frames": [
            {
                "id": "t01_t48",
                "lead": 48,
                "lead_label": "T01-T48",
                "valid_time": valid_time_bjt,
                "valid_label": "有效至 " + label_from_iso(valid_time_bjt),
                "file": published_file,
                "bytes": bytes_size
            }
        ]
    }

with open(manifest_path, "r") as f:
    data = json.load(f)

data["run_time"] = run_time_bjt
data["published_at"] = generated_at
data["note"] = "首页综合预报已接入 WORK_nx 最新稳定 T01-T48 降水拼图；图片按生成文件时间自动发布。"

products = data.get("products", [])
target = None
for product in products:
    if product.get("id") == "precip_24h":
        target = product
        break

if target is None:
    target = {
        "id": "precip_24h",
        "title": "WRF综合降水预报 T01-T48",
        "category": "模式预报",
        "unit": "mm",
        "color": "#087d7a",
        "legend": {
            "gradient": "linear-gradient(90deg, #e8f2f5, #9ad4ee, #4b93c4, #31a45f, #f2d34c, #e78935, #bd3434)",
            "ticks": ["0", "10", "25", "50", "100", "150+"]
        },
        "metrics": [],
        "frames": []
    }
    products.insert(0, target)
    data["products"] = products

target["title"] = "WRF综合降水预报 T01-T48"
target["category"] = "模式预报"
target["unit"] = "mm"
target["color"] = "#087d7a"
target["description"] = "WORK_nx 生成的 WRF 全降水逐小时综合预报拼图，按文件生成时间自动选择最新稳定 T48 产品。"
target["metrics"] = [
    {"label": "起报时间", "value": run_prefix},
    {"label": "生成时间", "value": label_from_iso(generated_at)},
    {"label": "图像大小", "value": "%.1f MB" % (bytes_size / 1048576.0)}
]
target["frames"] = [
    {
        "id": "t01_t48",
        "lead": 48,
        "lead_label": "T01-T48",
        "valid_time": valid_time_bjt,
        "valid_label": "有效至 " + label_from_iso(valid_time_bjt),
        "bytes": bytes_size,
        "file": published_file
    }
]
atomic_write_json(manifest_path, data)

if os.path.exists(catalog_path):
    with open(catalog_path, "r") as f:
        catalog = json.load(f)
else:
    catalog = {
        "schema_version": 1,
        "site": {"name": "IAP-LACS Forecast", "domain": "iaplacs.xyz"},
        "services": {}
    }

catalog["schema_version"] = catalog.get("schema_version", 1)
catalog["site"] = catalog.get("site") or data.get("site") or {"name": "IAP-LACS Forecast", "domain": "iaplacs.xyz"}
catalog["published_at"] = generated_at
services = catalog.setdefault("services", {})
main = services.setdefault("main", {})
main["title"] = "综合预报"
main["subtitle"] = "Comprehensive forecast"
main["note"] = "综合预报主页已接入 WORK_nx 最新稳定 T01-T48 降水拼图；发布时间使用图片文件生成时间。"

run_id = "worknx_" + run_prefix
new_run = {
    "id": run_id,
    "label": label_from_iso(run_time_bjt),
    "run_time": run_time_bjt,
    "published_at": generated_at,
    "summary": "WORK_nx 综合降水拼图，按文件生成时间发布",
    "products": [product_payload()]
}

runs = main.get("runs") or []
runs = [run for run in runs if run.get("id") != run_id]
runs.insert(0, new_run)
main["latest_run"] = run_id
main["runs"] = runs[:int(os.environ.get("IAPLACS_MAX_RUNS", "8"))]

atomic_write_json(catalog_path, catalog)
PY

CATALOG_BUILDER="$SITE_REPO/tools/build_forecast_catalog.py"
if [ ! -f "$CATALOG_BUILDER" ]; then
	echo "ERROR: forecast catalog builder not found: $CATALOG_BUILDER" >&2
	exit 1
fi
"$PYTHON_BIN" "$CATALOG_BUILDER"

git add data/current/manifest.json data/current/forecast-runs.json
if git diff --cached --quiet; then
	echo "No WORK_nx summary changes to commit for $RUN_PREFIX"
	prune_oss_assets
	exit 0
fi

git -c user.name="$GIT_USER_NAME" -c user.email="$GIT_USER_EMAIL" commit -m "Update WORK_nx summary ${RUN_PREFIX}"
git push origin HEAD:main
prune_oss_assets
REMOTE

echo "Published WORK_nx summary prefix: $run_prefix"
