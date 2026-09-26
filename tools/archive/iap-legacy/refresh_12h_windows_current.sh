#!/usr/bin/env bash

# Preserve the legacy runtime root when launched from the organized directory.
if [[ -L "$(dirname "${BASH_SOURCE[0]}")/.runtime-root" ]]; then
  exec bash "$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.runtime-root" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@"
fi

set -Eeuo pipefail

WEBSITE="${WEBSITE:-/data1/elpt_2022_00083/kerui/Website}"
NCL_BIN="${NCL_BIN:-/public/software/apps/ncl_ncarg/ncl630/bin/ncl}"
export NCARG_ROOT="${NCARG_ROOT:-/public/software/apps/ncl_ncarg/ncl630}"

render_windows() {
  local source_dir="$1" output_dir="$2"
  rm -rf "$output_dir"
  mkdir -p "$output_dir"
  RAIN_ACCUM_HOURS=12 \
    WORK_NX_WRF_DIR="$source_dir" \
    WORK_NX_NATIONAL_PNG_DIR="$output_dir" \
    WORK_NX_NATIONAL_PROVINCE_SHP_FILE="$WEBSITE/SHP/省界_region.shp" \
    "$NCL_BIN" "$WEBSITE/rain_worknx_national_hour_bjt.ncl"
}

copy_windows() {
  local output_dir="$1" target_dir="$2" target_prefix="$3" target_suffix="$4" source window
  while IFS= read -r source; do
    window="$(basename "$source")"
    window="${window#*_national_accum_12h_}"
    window="${window%_BJT.png}"
    cp -f "$source" "$target_dir/${target_prefix}${window}${target_suffix}"
  done < <(find "$output_dir" -maxdepth 1 -type f -name '*_national_accum_12h_*_BJT.png' | sort)
}

nx_dir="$WEBSITE/worknx_ningxia_overview/20260729_06"
yn_dir="$WEBSITE/worknx_yunnan_airports_overview/20260729_12"
sr_dir="$WEBSITE/wrf_hourly_png"

render_windows /data1/elpt_2022_00083/zhoubj/WORK_nx/2026072906/gfs/wrf "$WEBSITE/.tmp/national_12h_nx"
rm -f "$nx_dir"/Precip_accum_12h_WRF_Ningxia_T13_T48_InitUTC_2026-07-29_06_00_combined_overview_1x1_grid.*
copy_windows "$WEBSITE/.tmp/national_12h_nx" "$nx_dir" "Precip_accum_12h_WRF_Ningxia_T13_T48_InitUTC_2026-07-29_06_00_" "_combined_overview_1x1_grid.png"

render_windows /data1/elpt_2022_00083/zhoubj/WORK_yn/2026072912/gfs/wrf "$WEBSITE/.tmp/national_12h_yn"
rm -f "$yn_dir"/Precip_accum_12h_WRF_YunnanAirports_T13_T48_InitUTC_2026-07-29_12_00_combined_overview_1x1_grid.*
copy_windows "$WEBSITE/.tmp/national_12h_yn" "$yn_dir" "Precip_accum_12h_WRF_YunnanAirports_T13_T48_InitUTC_2026-07-29_12_00_" "_combined_overview_1x1_grid.png"

render_windows /data1/elpt_2022_00083/zhoubj/WORK/2026073000/gfs/wrf "$WEBSITE/.tmp/national_12h_sr"
rm -f "$sr_dir"/20260730_08_combined_accum_12h_*_BJT_grid.{png,webp,preview.webp}
copy_windows "$WEBSITE/.tmp/national_12h_sr" "$sr_dir" "20260730_08_combined_accum_12h_" "_BJT_grid.png"

for p in "$yn_dir"/Precip_accum_12h_WRF_YunnanAirports_T13_T48_InitUTC_2026-07-29_12_00_*.png "$sr_dir"/20260730_08_combined_accum_12h_*_BJT_grid.png; do
  convert "$p" -resize "3200x3200>" -strip -quality 92 -define webp:method=6 -define webp:use-sharp-yuv=true "${p%.png}.webp"
  convert "$p" -resize "1100x1100>" -strip -quality 70 -define webp:method=6 -define webp:use-sharp-yuv=true "${p%.png}.preview.webp"
done

ssh server02 'rm -f ~/iaplacs-site/data/current/maps/worknx_summary_20260729_06/Precip_accum_12h_WRF_Ningxia_T13_T48_InitUTC_2026-07-29_06_00_combined_overview_1x1_grid.* ~/iaplacs-site/data/current/maps/wrf_montage_20260730_08/20260730_08_combined_accum_12h_*'

for p in "$nx_dir"/Precip_accum_12h_WRF_Ningxia_T13_T48_InitUTC_2026-07-29_06_00_*.png; do
  WORK_NX_ROOT="$nx_dir" SOURCE_IMAGE_GLOB="$(basename "$p")" MIN_FILE_AGE_SECONDS=0 IAPLACS_WEBP_FORCE=1 IAPLACS_PREVIEW_FORCE=1 IAPLACS_ASSET_FORCE_UPLOAD=1 "$WEBSITE/publish_worknx_summary_to_github.sh"
done
RENDERER=/bin/true IAPLACS_WEBP_FORCE=0 IAPLACS_PREVIEW_FORCE=0 "$WEBSITE/publish_worknx_yunnan_airports_to_github.sh" --latest
PNG_DIR="$sr_dir" "$WEBSITE/publish_wrf_montage_to_github.sh" 20260730_08
