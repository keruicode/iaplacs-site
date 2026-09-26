#!/usr/bin/env bash
# Temporary Tianhe publisher: keep rendered maps in GitHub Pages, not OSS.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_REPO="${SITE_REPO:-$(cd "$SCRIPT_DIR/.." && pwd)}"
GIT_BIN="${GIT_BIN:-git}"
KEEP_RUNS="${IAPLACS_GITHUB_KEEP_RUNS:-5}"
KEEP_PNG="${IAPLACS_GITHUB_KEEP_PNG:-0}"
SOURCE_DIR=""
FAMILY=""
RUN_PREFIX=""
LOCAL_ONLY=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  publish_forecast_to_github_pages.sh \
    --source-dir /path/to/completed/run \
    --family worknx_summary|wrf_montage|airport_yunnan \
    --run-prefix YYYYMMDD_HH [--local-only] [--dry-run]

Copies the top-level rendered products from one completed run into the site
checkout, retains five runs for each product family, rebuilds the catalog with
relative GitHub Pages URLs, and commits/pushes the update. PNG files are
converted to WebP and removed by default; set IAPLACS_GITHUB_KEEP_PNG=1 to
retain PNG originals too.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '+ '
    printf '%q ' "$@"
    printf '\n'
    return
  fi
  "$@"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-dir)
      SOURCE_DIR="${2:-}"
      shift 2
      ;;
    --family)
      FAMILY="${2:-}"
      shift 2
      ;;
    --run-prefix)
      RUN_PREFIX="${2:-}"
      shift 2
      ;;
    --local-only)
      LOCAL_ONLY=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "unknown argument: $1"
      ;;
  esac
done

[[ -d "$SITE_REPO/.git" ]] || fail "SITE_REPO is not a Git checkout: $SITE_REPO"
[[ -d "$SOURCE_DIR" ]] || fail "source directory does not exist: $SOURCE_DIR"
[[ "$KEEP_RUNS" =~ ^[1-9][0-9]*$ ]] || fail "IAPLACS_GITHUB_KEEP_RUNS must be a positive integer"
[[ "$RUN_PREFIX" =~ ^[0-9]{8}_[0-9]{2}$ ]] || fail "run prefix must be YYYYMMDD_HH"
case "$FAMILY" in
  worknx_summary|wrf_montage|airport_yunnan) ;;
  *) fail "unsupported product family: $FAMILY" ;;
esac

MAPS_DIR="$SITE_REPO/data/current/maps"
DEST_DIR="$MAPS_DIR/${FAMILY}_${RUN_PREFIX}"
[[ "$DEST_DIR" == "$MAPS_DIR/"* ]] || fail "unsafe destination path"

if [[ "$DRY_RUN" != "1" ]]; then
  "$GIT_BIN" -C "$SITE_REPO" diff --quiet || fail "site checkout has unstaged changes"
  "$GIT_BIN" -C "$SITE_REPO" diff --cached --quiet || fail "site checkout has staged changes"
  "$GIT_BIN" -C "$SITE_REPO" pull --ff-only
fi

run mkdir -p "$DEST_DIR"
copied=0
while IFS= read -r -d '' source; do
  copied=$((copied + 1))
  run cp -p "$source" "$DEST_DIR/"
done < <(
  find "$SOURCE_DIR" -maxdepth 1 -type f \( \
    -iname '*.png' -o -iname '*.webp' -o -iname '*.jpg' -o -iname '*.jpeg' -o -name '*.json' \
  \) -print0
)
(( copied > 0 )) || fail "no top-level image or JSON files found in $SOURCE_DIR"

prune_family() {
  local family="$1"
  local -a runs=()
  local path
  while IFS= read -r -d '' path; do
    runs+=("$path")
  done < <(
    find "$MAPS_DIR" -maxdepth 1 -mindepth 1 -type d \
      -name "${family}_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9]" \
      -print0 | LC_ALL=C sort -rz
  )

  local index
  for ((index = KEEP_RUNS; index < ${#runs[@]}; index++)); do
    path="${runs[$index]}"
    [[ "$path" == "$MAPS_DIR/${family}_"* ]] || fail "unsafe retained-run path: $path"
    echo "removing old ${family} run: ${path##*/}"
    run rm -rf -- "$path"
  done
}

for family in worknx_summary wrf_montage airport_yunnan; do
  prune_family "$family"
done

if find "$MAPS_DIR" -type f -name '*.png' -print -quit | grep -q .; then
  run "$SITE_REPO/tools/optimize_forecast_images.sh"
fi

if [[ "$KEEP_PNG" != "1" ]]; then
  while IFS= read -r -d '' png; do
    run rm -f -- "$png"
  done < <(find "$DEST_DIR" -maxdepth 1 -type f -name '*.png' -print0)
fi

catalog_env=(
  "IAPLACS_MAX_RUNS=$KEEP_RUNS"
  "IAPLACS_ASSET_BASE_URL="
)
if [[ "$LOCAL_ONLY" == "1" ]]; then
  catalog_env+=("IAPLACS_MERGE_EXISTING_RUNS=0")
fi

if [[ "$DRY_RUN" == "1" ]]; then
  printf '+ env '
  printf '%q ' "${catalog_env[@]}"
  printf '%q ' python3 "$SITE_REPO/tools/build_forecast_catalog.py"
  printf '\n'
  exit 0
fi

env "${catalog_env[@]}" python3 "$SITE_REPO/tools/build_forecast_catalog.py"

while IFS= read -r -d '' run_dir; do
  "$GIT_BIN" -C "$SITE_REPO" add -f -- "$run_dir"
done < <(
  find "$MAPS_DIR" -maxdepth 1 -mindepth 1 -type d \( \
    -name 'worknx_summary_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9]' -o \
    -name 'wrf_montage_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9]' -o \
    -name 'airport_yunnan_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9]' \
  \) -print0
)
"$GIT_BIN" -C "$SITE_REPO" add -u -- data/current/maps
"$GIT_BIN" -C "$SITE_REPO" add -- data/current/forecast-runs.json

if "$GIT_BIN" -C "$SITE_REPO" diff --cached --quiet; then
  echo "no GitHub Pages changes to publish"
  exit 0
fi

if ! "$GIT_BIN" -C "$SITE_REPO" config user.name >/dev/null; then
  "$GIT_BIN" -C "$SITE_REPO" config user.name "IAP-LACS Forecast"
fi
if ! "$GIT_BIN" -C "$SITE_REPO" config user.email >/dev/null; then
  "$GIT_BIN" -C "$SITE_REPO" config user.email "forecast@iaplacs.xyz"
fi

"$GIT_BIN" -C "$SITE_REPO" commit -m "Publish ${FAMILY} ${RUN_PREFIX}"
"$GIT_BIN" -C "$SITE_REPO" push origin HEAD
