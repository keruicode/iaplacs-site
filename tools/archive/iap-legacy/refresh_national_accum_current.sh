#!/usr/bin/env bash

# Preserve the legacy runtime root when launched from the organized directory.
if [[ -L "$(dirname "${BASH_SOURCE[0]}")/.runtime-root" ]]; then
  exec bash "$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.runtime-root" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@"
fi

set -Eeuo pipefail

WEBSITE="${WEBSITE:-/data1/elpt_2022_00083/kerui/Website}"
NCL_BIN="${NCL_BIN:-/public/software/apps/ncl_ncarg/ncl630/bin/ncl}"
export NCARG_ROOT="${NCARG_ROOT:-/public/software/apps/ncl_ncarg/ncl630}"

render_national_accumulation() {
  local source_dir="$1" output_dir="$2" target_dir="$3" target_prefix="$4"
  local input source accum_hours target

  input="$(find "$source_dir" -maxdepth 1 -type f -name 'wrfout_d01_*' | sort | head -n 1)"
  [[ -n "$input" ]] || { echo "ERROR: no WRF input under $source_dir" >&2; return 1; }
  rm -rf "$output_dir"
  mkdir -p "$output_dir"

  for accum_hours in 12 24; do
    RAIN_ACCUM_HOURS="$accum_hours" \
      WORK_NX_WRF_DIR="$source_dir" \
      WORK_NX_NATIONAL_PNG_DIR="$output_dir" \
      WORK_NX_NATIONAL_PROVINCE_SHP_FILE="$WEBSITE/SHP/省界_region.shp" \
      "$NCL_BIN" "$WEBSITE/rain_worknx_national_hour_bjt.ncl"

    source="$(find "$output_dir" -maxdepth 1 -type f -name "*_national_accum_$(printf '%02d' "$accum_hours")h_*_BJT.png" | sort | head -n 1)"
    [[ -n "$source" ]] || { echo "ERROR: missing ${accum_hours}h national accumulation under $output_dir" >&2; return 1; }
    target="$target_dir/${target_prefix}${accum_hours}h.png"
    cp -f "$source" "$target"
    touch -r "$input" "$target"
    echo "Rendered national accumulation: $target"
  done
}

ningxia_dir="$WEBSITE/worknx_ningxia_overview/20260729_06"
airport_dir="$WEBSITE/worknx_yunnan_airports_overview/20260729_12"
shangrao_dir="$WEBSITE/wrf_hourly_png"

render_national_accumulation \
  /data1/elpt_2022_00083/zhoubj/WORK_nx/2026072906/gfs/wrf \
  "$WEBSITE/.tmp/national_accum_ningxia" \
  "$ningxia_dir" \
  "Precip_accum_"
mv "$ningxia_dir/Precip_accum_12h.png" "$ningxia_dir/Precip_accum_12h_WRF_Ningxia_T13_T48_InitUTC_2026-07-29_06_00_combined_overview_1x1_grid.png"
mv "$ningxia_dir/Precip_accum_24h.png" "$ningxia_dir/Precip_accum_24h_WRF_Ningxia_T13_T48_InitUTC_2026-07-29_06_00_combined_overview_1x1_grid.png"

render_national_accumulation \
  /data1/elpt_2022_00083/zhoubj/WORK_yn/2026072912/gfs/wrf \
  "$WEBSITE/.tmp/national_accum_airport" \
  "$airport_dir" \
  "Precip_accum_"
mv "$airport_dir/Precip_accum_12h.png" "$airport_dir/Precip_accum_12h_WRF_YunnanAirports_T13_T48_InitUTC_2026-07-29_12_00_combined_overview_1x1_grid.png"
mv "$airport_dir/Precip_accum_24h.png" "$airport_dir/Precip_accum_24h_WRF_YunnanAirports_T13_T48_InitUTC_2026-07-29_12_00_combined_overview_1x1_grid.png"

render_national_accumulation \
  /data1/elpt_2022_00083/zhoubj/WORK/2026073000/gfs/wrf \
  "$WEBSITE/.tmp/national_accum_shangrao" \
  "$shangrao_dir" \
  "20260730_08_combined_accum_"
for accum_hours in 12 24; do
  source="$shangrao_dir/20260730_08_combined_accum_${accum_hours}h.png"
  target="$(find "$shangrao_dir" -maxdepth 1 -type f -name "20260730_08_combined_accum_$(printf '%02d' "$accum_hours")h_*_BJT_grid.png" | sort | head -n 1)"
  [[ -n "$target" ]] || { echo "ERROR: missing existing Shangrao ${accum_hours}h product target" >&2; exit 1; }
  mv "$source" "$target"
done

for accum_hours in 12 24; do
  WORK_NX_ROOT="$ningxia_dir" \
    SOURCE_IMAGE_GLOB="Precip_accum_${accum_hours}h_WRF_Ningxia_T13_T48_InitUTC_2026-07-29_06_00_combined_overview_1x1_grid.png" \
    MIN_FILE_AGE_SECONDS=0 \
    IAPLACS_WEBP_FORCE=1 IAPLACS_PREVIEW_FORCE=1 IAPLACS_ASSET_FORCE_UPLOAD=1 \
    "$WEBSITE/publish_worknx_summary_to_github.sh"
done

RENDERER=/bin/true IAPLACS_WEBP_FORCE=1 IAPLACS_PREVIEW_FORCE=1 \
  "$WEBSITE/publish_worknx_yunnan_airports_to_github.sh" --latest
PNG_DIR="$shangrao_dir" IAPLACS_PREVIEW_FORCE=1 \
  "$WEBSITE/publish_wrf_montage_to_github.sh" 20260730_08
