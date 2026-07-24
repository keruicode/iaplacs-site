#!/usr/bin/env bash

# Run on Tianhe. Publish newly completed WORK_nx and WORK_yn forecast maps
# directly to GitHub Pages and retain only five runs per product family.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIANHE_HOME="${TIANHE_HOME:-/fs2/home/junzhang}"
TIANHE_BASHRC="${TIANHE_BASHRC:-$TIANHE_HOME/kerui/bashrc}"

# The Kerui login environment supplies the Tianhe HTTP(S) proxy used for
# GitHub.  Cron starts with a minimal environment, so load it explicitly.
if [[ -r "$TIANHE_BASHRC" ]]; then
  set +u
  # shellcheck disable=SC1090
  source "$TIANHE_BASHRC"
  set -u
fi

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
RENDER_ROOT="${IAPLACS_TIANHE_RENDER_ROOT:-$STATE_DIR/rendered}"
NCL_COMMAND_RUNNER="${IAPLACS_TIANHE_NCL_COMMAND_RUNNER:-$SCRIPT_DIR/run_tianhe_conda_command.sh}"
NINGXIA_NCL_RENDERER="${IAPLACS_TIANHE_NINGXIA_NCL_RENDERER:-$SCRIPT_DIR/render_worknx_ningxia_overview.sh}"
YUNNAN_NCL_RENDERER="${IAPLACS_TIANHE_YUNNAN_NCL_RENDERER:-$SCRIPT_DIR/render_worknx_yunnan_airports_overview.sh}"
NINGXIA_CITY_SHP_FILE="${NINGXIA_CITY_SHP_FILE:-$SCRIPT_DIR/SHP/ningxia_city_county.shp}"
YUNNAN_CITY_SHP_FILE="${YUNNAN_CITY_SHP_FILE:-$SCRIPT_DIR/SHP/yunnan_city.shp}"
KEEP_RUNS="${IAPLACS_TIANHE_KEEP_RUNS:-5}"
MIN_FILE_AGE_SECONDS="${IAPLACS_TIANHE_MIN_FILE_AGE_SECONDS:-1200}"
MIN_WRFOUT_BYTES="${IAPLACS_TIANHE_MIN_WRFOUT_BYTES:-20000000000}"
GIT_NETWORK_TIMEOUT="${IAPLACS_TIANHE_GIT_NETWORK_TIMEOUT:-120}"
GIT_NETWORK_ATTEMPTS="${IAPLACS_TIANHE_GIT_NETWORK_ATTEMPTS:-2}"
GIT_NETWORK_RETRY_DELAY="${IAPLACS_TIANHE_GIT_NETWORK_RETRY_DELAY:-20}"
DRY_RUN=0
FORCE=0

usage() {
  cat <<'EOF'
Usage: tianhe_publish_forecast_to_github.sh [--dry-run] [--force]

Finds the newest stable Tianhe WORK_nx and WORK_yn wrfout files, renders the
regional precipitation figures, retains five runs per family, rebuilds
data/tianhe/current/forecast-runs.json, then pushes to origin.
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
[[ -x "$NCL_COMMAND_RUNNER" ]] || fail "Tianhe NCL command runner is not executable: $NCL_COMMAND_RUNNER"
[[ -x "$NINGXIA_NCL_RENDERER" ]] || fail "Ningxia NCL renderer is not executable: $NINGXIA_NCL_RENDERER"
[[ -x "$YUNNAN_NCL_RENDERER" ]] || fail "Yunnan NCL renderer is not executable: $YUNNAN_NCL_RENDERER"
[[ "$KEEP_RUNS" =~ ^[1-9][0-9]*$ ]] || fail "IAPLACS_TIANHE_KEEP_RUNS must be a positive integer"
[[ "$MIN_FILE_AGE_SECONDS" =~ ^[0-9]+$ ]] || fail "IAPLACS_TIANHE_MIN_FILE_AGE_SECONDS must be a non-negative integer"
[[ "$MIN_WRFOUT_BYTES" =~ ^[1-9][0-9]*$ ]] || fail "IAPLACS_TIANHE_MIN_WRFOUT_BYTES must be a positive integer"
[[ "$GIT_NETWORK_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || fail "IAPLACS_TIANHE_GIT_NETWORK_TIMEOUT must be a positive integer"
[[ "$GIT_NETWORK_ATTEMPTS" =~ ^[1-9][0-9]*$ ]] || fail "IAPLACS_TIANHE_GIT_NETWORK_ATTEMPTS must be a positive integer"
[[ "$GIT_NETWORK_RETRY_DELAY" =~ ^[0-9]+$ ]] || fail "IAPLACS_TIANHE_GIT_NETWORK_RETRY_DELAY must be a non-negative integer"
command -v "$GIT_BIN" >/dev/null || fail "git command not found: $GIT_BIN"
"$PYTHON_BIN" -c 'import matplotlib, netCDF4, PIL, shapefile' >/dev/null \
  || fail "Tianhe Python is missing matplotlib, netCDF4, Pillow, or pyshp"

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
      else
        status=$?
      fi
    else
      if "$GIT_BIN" "$@"; then
        return 0
      else
        status=$?
      fi
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

latest_complete_run() {
  local work_root="$1"
  local run_id run_root

  while IFS= read -r run_id; do
    run_root="$work_root/$run_id"
    if [[ -n "$(matching_wrfout "$run_root")" ]]; then
      printf '%s\n' "$run_id"
      return 0
    fi
  done < <(
    find "$work_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
      | LC_ALL=C awk '/^[0-9]{10}$/' \
      | LC_ALL=C sort -r
  )
  return 1
}

matching_wrfout() {
  local run_root="$1"
  local candidate now_epoch source_epoch source_size
  now_epoch="$(date +%s)"
  while IFS= read -r candidate; do
    source_epoch="$(stat -c '%Y' "$candidate")"
    source_size="$(stat -c '%s' "$candidate")"
    if (( now_epoch - source_epoch >= MIN_FILE_AGE_SECONDS )) && \
      (( source_size >= MIN_WRFOUT_BYTES )); then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(
    find "$run_root/gfs/wrf" -maxdepth 1 -type f -name 'wrfout_d01_*' -size +0c -printf '%p\n' 2>/dev/null \
      | LC_ALL=C sort
  )
  return 1
}

complete_run_present() {
  local destination="$1"
  shift
  [[ -d "$destination" ]] || return 1
  local source base stem
  for source in "$@"; do
    base="$(basename "$source")"
    if [[ "$base" == *.json ]]; then
      [[ -s "$destination/$base" ]] || return 1
      continue
    fi
    stem="${base%.*}"
    compgen -G "$destination/$stem.webp" >/dev/null || \
      compgen -G "$destination/$stem.png" >/dev/null || return 1
  done
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
  local destination="$MAPS_DIR/${family}_${run_id:0:8}_${run_id:8:2}"
  local source

  [[ "$run_id" =~ ^[0-9]{10}$ ]] || fail "invalid Tianhe run id: $run_id"
  (( $# > 0 )) || return
  if [[ "$FORCE" != "1" ]] && complete_run_present "$destination" "$@"; then
    echo "already published: ${destination##*/}"
    return
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'would publish: %s from Tianhe run %s (%d source file(s))\n' "$family" "$run_id" "$#"
    return
  fi

  mkdir -p "$destination"
  find "$destination" -maxdepth 1 -type f \( -name '*.png' -o -name '*.webp' -o -name '*.json' \) -delete
  for source in "$@"; do
    [[ -s "$source" ]] || fail "missing completed source: $source"
    cp -p "$source" "$destination/"
  done
  CHANGED_RUNS+=("${family}_${run_id}")
}

render_product() {
  local mode="$1"
  local run_id="$2"
  local wrf_dir="$3"
  local city_shp="$4"
  local stamp="${run_id:0:4}-${run_id:4:2}-${run_id:6:2}_${run_id:8:2}_00"
  local family output_name output_dir output renderer work_root run_root province_shp

  if [[ "$mode" == "ningxia" ]]; then
    family="worknx_summary"
    output_name="Precip_hourly_WRF_Ningxia_T13_T48_InitUTC_${stamp}_combined_overview_6x6_grid.png"
    renderer="$NINGXIA_NCL_RENDERER"
    work_root="$WORK_NX_ROOT"
    province_shp="${NINGXIA_PROVINCE_SHP_FILE:-$SCRIPT_DIR/SHP/省界_region.shp}"
  else
    family="airport_yunnan"
    output_name="Precip_hourly_WRF_YunnanAirports_T13_T48_InitUTC_${stamp}_combined_overview_6x6_grid.png"
    renderer="$YUNNAN_NCL_RENDERER"
    work_root="$WORK_YN_ROOT"
    province_shp="${YUNNAN_PROVINCE_SHP_FILE:-$SCRIPT_DIR/SHP/省界_region.shp}"
  fi
  run_root="$work_root/$run_id"
  output_dir="$RENDER_ROOT/$family/${run_id:0:8}_${run_id:8:2}"
  output="$output_dir/$output_name"

  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'would render: %s from %s\n' "$output_name" "$wrf_dir" >&2
    printf '%s\n' "$output"
    return
  fi

  if [[ ! -s "$output" || "$FORCE" == "1" || ( "$mode" == "yunnan" && ! -s "$output_dir/airport_precip_totals.json" ) ]]; then
    mkdir -p "$output_dir"
    if [[ "$mode" == "ningxia" ]]; then
      MIN_FILE_AGE_SECONDS="$MIN_FILE_AGE_SECONDS" \
        MIN_WRFOUT_BYTES="$MIN_WRFOUT_BYTES" \
        WORK_NX_ROOT="$run_root" \
        OUTPUT_ROOT="$RENDER_ROOT/$family" \
        NINGXIA_PROVINCE_SHP_FILE="$province_shp" \
        NINGXIA_COUNTY_SHP_FILE="$city_shp" \
        "$NCL_COMMAND_RUNNER" "$renderer" --latest >&2
    else
      MIN_FILE_AGE_SECONDS="$MIN_FILE_AGE_SECONDS" \
        MIN_WRFOUT_BYTES="$MIN_WRFOUT_BYTES" \
        WORK_YN_ROOT="$run_root" \
        OUTPUT_ROOT="$RENDER_ROOT/$family" \
        YUNNAN_PROVINCE_SHP_FILE="$province_shp" \
        YUNNAN_CITY_SHP_FILE="$city_shp" \
        PYTHON_BIN="$PYTHON_BIN" \
        "$NCL_COMMAND_RUNNER" "$renderer" --latest >&2
    fi
  fi
  [[ -s "$output" ]] || fail "Tianhe renderer did not create: $output"
  printf '%s\n' "$output"
}

nx_run="$(latest_complete_run "$WORK_NX_ROOT" || true)"
if [[ -n "$nx_run" ]]; then
  nx_run_root="$WORK_NX_ROOT/$nx_run"
  nx_wrfout="$(matching_wrfout "$nx_run_root")"
  if [[ -n "$nx_wrfout" ]]; then
    nx_region="$(render_product "ningxia" "$nx_run" "$(dirname "$nx_wrfout")" "$NINGXIA_CITY_SHP_FILE")"
    relay_family "worknx_summary" "$nx_run" "$nx_region"
  else
    echo "WORK_nx run $nx_run is incomplete; waiting for stable WRF output"
  fi
else
  echo "no complete WORK_nx run found; waiting for stable WRF output"
fi

yn_run="$(latest_complete_run "$WORK_YN_ROOT" || true)"
if [[ -n "$yn_run" ]]; then
  yn_run_root="$WORK_YN_ROOT/$yn_run"
  yn_wrfout="$(matching_wrfout "$yn_run_root")"
  if [[ -n "$yn_wrfout" ]]; then
    yn_overview="$(render_product "yunnan" "$yn_run" "$(dirname "$yn_wrfout")" "$YUNNAN_CITY_SHP_FILE")"
    yn_totals="$(dirname "$yn_overview")/airport_precip_totals.json"
    relay_family "airport_yunnan" "$yn_run" "$yn_overview" "$yn_totals"
  else
    echo "WORK_yn run $yn_run is incomplete; waiting for stable WRF output"
  fi
else
  echo "no complete WORK_yn run found; waiting for stable WRF output"
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
