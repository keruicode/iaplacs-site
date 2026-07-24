#!/usr/bin/env bash

# Run a Tianhe command in the dedicated NCL environment. Cron does not load a
# login shell, so source the user's Conda bootstrap explicitly before use.
set -Eeuo pipefail

CONDA_BASHRC="${TIANHE_CONDA_BASHRC:-/fs2/home/junzhang/kerui/bashrc}"
CONDA_ENV_NAME="${TIANHE_NCL_ENV:-ncl}"

[[ -r "$CONDA_BASHRC" ]] || {
  echo "ERROR: Tianhe Conda bootstrap is unreadable: $CONDA_BASHRC" >&2
  exit 1
}

# shellcheck disable=SC1090
source "$CONDA_BASHRC"
conda activate "$CONDA_ENV_NAME"
export NCL_BIN="${NCL_BIN:-$(command -v ncl)}"
export NCL_ROOT="${NCL_ROOT:-${NCARG_ROOT:-}}"
[[ -x "$NCL_BIN" ]] || {
  echo "ERROR: ncl is unavailable in Conda environment $CONDA_ENV_NAME" >&2
  exit 127
}
[[ -d "$NCL_ROOT/lib/ncarg" ]] || {
  echo "ERROR: NCARG_ROOT is invalid after Conda activation: $NCL_ROOT" >&2
  exit 127
}

# The Tianhe account has ImageMagick already downloaded in Conda's package
# cache.  It is not yet linked into the minimal NCL environment, so expose its
# original binaries and cached shared libraries to the unchanged 寰 scripts.
if ! command -v montage >/dev/null 2>&1; then
  CONDA_BASE="$(dirname "$(dirname "$CONDA_EXE")")"
  IMAGEMAGICK_CACHE_DIR="${TIANHE_IMAGEMAGICK_CACHE_DIR:-}"
  if [[ -z "$IMAGEMAGICK_CACHE_DIR" ]]; then
    IMAGEMAGICK_CACHE_DIR="$(find "$CONDA_BASE/pkgs" -maxdepth 1 -type d -name 'imagemagick-*' -print | LC_ALL=C sort | tail -n 1)"
  fi
  [[ -x "$IMAGEMAGICK_CACHE_DIR/bin/montage" ]] || {
    echo "ERROR: ImageMagick is unavailable in the NCL environment or Conda cache" >&2
    exit 127
  }
  CACHE_LIBRARY_PATH="$(find "$CONDA_BASE/pkgs" -mindepth 2 -maxdepth 2 -type d -name lib -print | paste -sd: -)"
  export PATH="$IMAGEMAGICK_CACHE_DIR/bin:$PATH"
  export LD_LIBRARY_PATH="$CONDA_PREFIX/lib:$CACHE_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

command -v convert >/dev/null || {
  echo "ERROR: ImageMagick convert is unavailable" >&2
  exit 127
}
exec "$@"
