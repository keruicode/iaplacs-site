#!/usr/bin/env bash

# Run on Tianhe. Publish newly completed WORK_nx and WORK_yn forecast maps
# directly to GitHub Pages and retain only five runs per product family.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIANHE_HOME="${TIANHE_HOME:-/fs2/home/junzhang}"
WORK_NX_ROOT="${WORK_NX_ROOT:-$TIANHE_HOME/zhoubj/WORK_nx}"
WORK_YN_ROOT="${WORK_YN_ROOT:-$TIANHE_HOME/zhoubj/WORK_yn}"
SITE_REPO="${SITE_REPO:-$TIANHE_HOME/kerui/iaplacs-site}"
GIT_REMOTE_URL="${GIT_REMOTE_URL:-https://github.com/keruicode/iaplacs-site.git}"
if [[ -n "${GIT_BIN:-}" ]]; then
  GIT_BIN="$GIT_BIN"
elif [[ -x "$TIANHE_HOME/kerui/bin/git-system" ]]; then
  GIT_BIN="$TIANHE_HOME/kerui/bin/git-system"
else
  GIT_BIN="git"
fi
PYTHON_BIN="${PYTHON_BIN:-$TIANHE_HOME/zhoubj/conda_envs/wrf-scripts/bin/python}"
STATE_DIR="${IAPLACS_TIANHE_STATE_DIR:-$HOME/.iaplacs-tianhe}"
KEEP_RUNS="${IAPLACS_TIANHE_KEEP_RUNS:-5}"
GIT_NETWORK_TIMEOUT="${IAPLACS_TIANHE_GIT_NETWORK_TIMEOUT:-120}"
GIT_NETWORK_ATTEMPTS="${IAPLACS_TIANHE_GIT_NETWORK_ATTEMPTS:-2}"
GIT_NETWORK_RETRY_DELAY="${IAPLACS_TIANHE_GIT_NETWORK_RETRY_DELAY:-20}"
DRY_RUN=0
FORCE=0

usage() {
  cat <<'EOF'
Usage: tianhe_publish_forecast_to_github.sh [--dry-run] [--force]

Finds the newest complete Tianhe WORK_nx and WORK_yn rendered precipitation
figures, publishes them into the GitHub Pages checkout, retains five runs per
family, rebuilds data/tianhe/current/forecast-runs.json, then pushes to origin.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --force)
      FORCE=1
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

[[ -d "$WORK_NX_ROOT" ]] || fail "WORK_nx directory does not exist: $WORK_NX_ROOT"
[[ -d "$WORK_YN_ROOT" ]] || fail "WORK_yn directory does not exist: $WORK_YN_ROOT"
[[ -x "$PYTHON_BIN" ]] || fail "Python environment is not executable: $PYTHON_BIN"
[[ "$KEEP_RUNS" =~ ^[1-9][0-9]*$ ]] || fail "IAPLACS_TIANHE_KEEP_RUNS must be a positive integer"
[[ "$GIT_NETWORK_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || fail "IAPLACS_TIANHE_GIT_NETWORK_TIMEOUT must be a positive integer"
[[ "$GIT_NETWORK_ATTEMPTS" =~ ^[1-9][0-9]*$ ]] || fail "IAPLACS_TIANHE_GIT_NETWORK_ATTEMPTS must be a positive integer"
[[ "$GIT_NETWORK_RETRY_DELAY" =~ ^[0-9]+$ ]] || fail "IAPLACS_TIANHE_GIT_NETWORK_RETRY_DELAY must be a non-negative integer"
command -v "$GIT_BIN" >/dev/null || fail "git command not found: $GIT_BIN"

mkdir -p "$STATE_DIR"
LOCK_DIR="$STATE_DIR/publisher.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "another Tianhe publisher is already running"
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

ensure_site_checkout() {
  if [[ -d "$SITE_REPO/.git" ]]; then
    return
  fi
  [[ ! -e "$SITE_REPO" ]] || fail "SITE_REPO exists but is not a Git checkout: $SITE_REPO"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "would clone GitHub Pages checkout: $GIT_REMOTE_URL -> $SITE_REPO"
    return
  fi
  mkdir -p "$(dirname "$SITE_REPO")"
  run_git_network clone --branch main --single-branch "$GIT_REMOTE_URL" "$SITE_REPO"
}

run_git_network() {
  local attempt=1
  local status=0

  while (( attempt <= GIT_NETWORK_ATTEMPTS )); do
    if command -v timeout >/dev/null 2>&1; then
      if timeout "$GIT_NETWORK_TIMEOUT" "$GIT_BIN" "$@"; then
        return 0
      fi
      status=$?
    else
      if "$GIT_BIN" "$@"; then
        return 0
      fi
      status=$?
    fi

    if (( attempt == GIT_NETWORK_ATTEMPTS )); then
      return "$status"
    fi
    echo "Git network attempt $attempt/$GIT_NETWORK_ATTEMPTS failed; retrying in ${GIT_NETWORK_RETRY_DELAY}s" >&2
    sleep "$GIT_NETWORK_RETRY_DELAY"
    attempt=$((attempt + 1))
  done
}

latest_run() {
  local work_root="$1"
  find "$work_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | LC_ALL=C awk '/^[0-9]{10}$/' \
    | LC_ALL=C sort -r \
    | head -n 1
}

matching_figure() {
  local run_root="$1"
  local file_pattern="$2"
  find "$run_root/gfs/wrf" -maxdepth 1 -type f -name "$file_pattern" -size +0c -printf '%p\n' 2>/dev/null \
    | LC_ALL=C sort \
    | head -n 1
}

complete_run_present() {
  local destination="$1"
  local expected_count="$2"
  [[ -d "$destination" ]] || return 1
  local count
  count="$(find "$destination" -maxdepth 1 -type f \( \( -name '*.webp' ! -name '*.preview.webp' \) -o -name '*.png' \) | wc -l | tr -d ' ')"
  [[ "$count" -ge "$expected_count" ]]
}

prune_family() {
  local maps_dir="$1"
  local family="$2"
  local count=0
  local directory
  while IFS= read -r directory; do
    count=$((count + 1))
    if (( count > KEEP_RUNS )); then
      [[ "$directory" == "$maps_dir/${family}_"* ]] || fail "unsafe retained-run path: $directory"
      echo "removing old Tianhe run: ${directory##*/}"
      rm -rf -- "$directory"
    fi
  done < <(
    find "$maps_dir" -maxdepth 1 -mindepth 1 -type d \
      -name "${family}_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9]" \
      -print | LC_ALL=C sort -r
  )
}

ensure_site_checkout
if [[ "$DRY_RUN" == "1" && ! -d "$SITE_REPO/.git" ]]; then
  exit 0
fi

MAPS_DIR="$SITE_REPO/data/tianhe/current/maps"
CATALOG_PATH="$SITE_REPO/data/tianhe/current/forecast-runs.json"
[[ -f "$SITE_REPO/tools/build_tianhe_forecast_catalog.py" ]] || fail "missing catalog builder in $SITE_REPO"

if [[ "$DRY_RUN" != "1" ]]; then
  "$GIT_BIN" -C "$SITE_REPO" diff --quiet -- data/tianhe || fail "uncommitted Tianhe data changes in $SITE_REPO"
  "$GIT_BIN" -C "$SITE_REPO" diff --cached --quiet -- data/tianhe || fail "staged Tianhe data changes in $SITE_REPO"
  if ! run_git_network -C "$SITE_REPO" pull --ff-only origin main; then
    echo "WARNING: GitHub pull failed; continuing with the local Tianhe checkout" >&2
  fi
fi

CHANGED_RUNS=()
relay_family() {
  local family="$1"
  local run_id="$2"
  shift 2
  local expected_count="$#"
  local destination="$MAPS_DIR/${family}_${run_id:0:8}_${run_id:8:2}"
  local source

  [[ "$run_id" =~ ^[0-9]{10}$ ]] || fail "invalid Tianhe run id: $run_id"
  (( expected_count > 0 )) || return
  if [[ "$FORCE" != "1" ]] && complete_run_present "$destination" "$expected_count"; then
    echo "already published: ${destination##*/}"
    return
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'would publish: %s from Tianhe run %s (%d figure(s))\n' "$family" "$run_id" "$expected_count"
    return
  fi

  mkdir -p "$destination"
  find "$destination" -maxdepth 1 -type f \( -name '*.png' -o -name '*.webp' \) -delete
  for source in "$@"; do
    [[ -s "$source" ]] || fail "missing completed figure: $source"
    cp -p "$source" "$destination/"
  done
  CHANGED_RUNS+=("${family}_${run_id}")
}

nx_run="$(latest_run "$WORK_NX_ROOT")"
if [[ -n "$nx_run" ]]; then
  nx_figure="$(matching_figure "$WORK_NX_ROOT/$nx_run" 'Precip_hourly_WRF_AllRain_T01_T48_InitUTC_*.png')"
  if [[ -n "$nx_figure" ]]; then
    relay_family "worknx_summary" "$nx_run" "$nx_figure"
  else
    echo "WORK_nx run $nx_run has no completed precipitation figure"
  fi
else
  echo "no completed WORK_nx run found"
fi

yn_run="$(latest_run "$WORK_YN_ROOT")"
if [[ -n "$yn_run" ]]; then
  yn_domain="$(matching_figure "$WORK_YN_ROOT/$yn_run" 'Precip_hourly_YunnanDomain_TargetT07_T48_ActualT07_T48_InitUTC_*.png')"
  yn_local="$(matching_figure "$WORK_YN_ROOT/$yn_run" 'Precip_hourly_YunnanLocal_TargetT07_T48_ActualT07_T48_InitUTC_*.png')"
  if [[ -n "$yn_domain" && -n "$yn_local" ]]; then
    relay_family "airport_yunnan" "$yn_run" "$yn_domain" "$yn_local"
  else
    echo "WORK_yn run $yn_run is incomplete; waiting for both Yunnan precipitation figures"
  fi
else
  echo "no completed WORK_yn run found"
fi

if [[ "$DRY_RUN" == "1" ]]; then
  exit 0
fi

if (( ${#CHANGED_RUNS[@]} == 0 )); then
  if "$GIT_BIN" -C "$SITE_REPO" log --format=%H origin/main..HEAD | grep -q .; then
    run_git_network -C "$SITE_REPO" push origin main
    echo "pushed a previously committed Tianhe update"
  else
    echo "no new Tianhe forecast products to publish"
  fi
  exit 0
fi

if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
  IAPLACS_MAPS_DIR="$MAPS_DIR" "$SITE_REPO/tools/optimize_forecast_images.sh"
  find "$MAPS_DIR" -type f -name '*.png' -delete
elif "$PYTHON_BIN" -c 'import PIL' >/dev/null 2>&1; then
  "$PYTHON_BIN" "$SITE_REPO/tools/optimize_tianhe_forecast_images.py" --maps-dir "$MAPS_DIR"
  find "$MAPS_DIR" -type f -name '*.png' -delete
else
  echo "WARNING: ImageMagick is unavailable; publishing PNG files without WebP optimization" >&2
fi

prune_family "$MAPS_DIR" "worknx_summary"
prune_family "$MAPS_DIR" "airport_yunnan"
IAPLACS_MAX_RUNS="$KEEP_RUNS" "$PYTHON_BIN" "$SITE_REPO/tools/build_tianhe_forecast_catalog.py"
"$GIT_BIN" -C "$SITE_REPO" add -A -- data/tianhe/current/maps "$CATALOG_PATH"

if "$GIT_BIN" -C "$SITE_REPO" diff --cached --quiet -- data/tianhe; then
  echo "Tianhe catalog is already current"
  exit 0
fi

if ! "$GIT_BIN" -C "$SITE_REPO" config user.name >/dev/null; then
  "$GIT_BIN" -C "$SITE_REPO" config user.name "IAP-LACS Forecast"
fi
if ! "$GIT_BIN" -C "$SITE_REPO" config user.email >/dev/null; then
  "$GIT_BIN" -C "$SITE_REPO" config user.email "forecast@iaplacs.xyz"
fi

commit_label="${CHANGED_RUNS[*]}"
"$GIT_BIN" -C "$SITE_REPO" commit -m "Publish Tianhe forecasts $commit_label" -- data/tianhe/current/maps "$CATALOG_PATH"
run_git_network -C "$SITE_REPO" push origin main
echo "published Tianhe forecasts: $commit_label"
