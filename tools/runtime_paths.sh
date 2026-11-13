#!/usr/bin/env bash

# Code lives in scripts/ on IAP; data, logs and assets remain in Website/.
IAPLACS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cron does not inherit the interactive Slurm PATH on IAP.
if ! command -v squeue >/dev/null 2>&1; then
  slurm_bin="${IAPLACS_SLURM_BIN:-/opt/gridview/slurm/bin}"
  if [[ -x "$slurm_bin/squeue" && -x "$slurm_bin/sbatch" ]]; then
    export PATH="$slurm_bin:$PATH"
  fi
  unset slurm_bin
fi

# Set before any inline Python or image tool starts, not after its imports.
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export BLIS_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1
export MAGICK_THREAD_LIMIT=1

iaplacs_runtime_root() {
  local candidate="$1"
  if [[ -L "$candidate/.runtime-root" ]]; then
    (cd -P "$candidate/.runtime-root" && pwd)
  else
    printf '%s\n' "$candidate"
  fi
}

iaplacs_script_root() {
  local candidate="$1"
  if [[ -f "$candidate/scripts/runtime_paths.sh" ]]; then
    printf '%s/scripts\n' "$candidate"
  else
    printf '%s\n' "$candidate"
  fi
}

# Guard before entry scripts can import Python, read NetCDF, or render NCL.
# Transfer-only remote publication steps and SSH recovery are not renderers.
case "$(basename "$0")" in
  validate_plot_job.sh|run_website_cycle.sh|audit_iap_forecast_publication.sh|publish_bjt06_partial_forecasts.sh|\
  publish_workyn_yunnan_airports_if_new.sh|publish_worknx_ningxia_to_github.sh|\
  publish_workxj_xinjiang_to_github.sh|publish_worknx_yunnan_airports_to_github.sh|\
  publish_work_visibility.sh|publish_yunnan_radar.sh|publish_supercooled_water_path.sh|\
  render_worknx_ningxia_overview.sh|render_worknx_yunnan_airports_overview.sh|\
  auto_pipeline_server.sh|make_wrf_montages.sh|optimize_forecast_images.sh|\
  publish_worknx_summary_to_github.sh|publish_wrf_montage_to_github.sh|\
  publish_wrf_montages_with_hourly_to_github.sh|publish_hourly_panels_to_oss.sh|\
  publish_airport_aviation_to_oss.sh|publish_wrf_hourly_panels_to_oss.sh)
    [[ -r "$IAPLACS_SCRIPT_DIR/plot_scheduler.sh" ]] || {
      echo 'ERROR: plot scheduler missing; refusing direct execution' >&2
      exit 77
    }
    source "$IAPLACS_SCRIPT_DIR/plot_scheduler.sh" || exit 77
    iaplacs_plot_entry "$IAPLACS_SCRIPT_DIR/$(basename "$0")" "$@"
    ;;
esac
