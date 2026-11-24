#!/usr/bin/env bash
# Linux compute-node smoke test; no WRF reads, network or live publication.
set -Eeuo pipefail
case "${0##*/}" in
  render*)
    exit 0 ;;
  publish_worknx_summary_to_github.sh)
    [[ -d "$NX_BATCH_DIR" && "$PUBLISH_FAMILY" == worknx_summary ]]
    echo "${NX_BATCH_COMMIT:-0} $SOURCE_IMAGE_GLOB" >> "$calls"
    if [[ ${NX_BATCH_COMMIT:-0} == 1 ]]; then
      [[ -s "$NX_BATCH_DIR/supercooled/production_manifest.json" ]]
      [[ ! -e "$OUTPUT_ROOT/$run/supercooled/.published-sha256" ]]
      exit "${commit_rc:-0}"
    fi
    exit 0 ;;
  publish_work_visibility.sh) exit 75 ;;
  publish_yunnan_radar.sh|publish_hourly_panels_to_oss.sh) exit 0 ;;
  publish_supercooled_water_path.sh)
    mkdir "$NX_BATCH_DIR/supercooled"
    echo '{}' > "$NX_BATCH_DIR/supercooled/production_manifest.json"
    exit 0 ;;
esac
tools="$(cd "$(dirname "$0")/.." && pwd)"
root="$(mktemp -d)"
trap 'rm -rf -- "$root"' EXIT
export OUTPUT_ROOT="$root/maps" run=20261124_00 calls="$root/calls"
mkdir -p "$OUTPUT_ROOT/$run/supercooled"
cp "$tools/publish_worknx_ningxia_to_github.sh" "$root/"
printf '%s\n' 'IAPLACS_SCRIPT_DIR="$(dirname "$0")"' 'iaplacs_runtime_root() { echo "$1"; }' > "$root/runtime_paths.sh"
for name in render_worknx_ningxia_overview publish_worknx_summary_to_github publish_hourly_panels_to_oss publish_work_visibility publish_yunnan_radar publish_supercooled_water_path; do
  cp "$0" "$root/$name.sh"
  chmod +x "$root/$name.sh"
done
for region in Ningxia AllRain NingxiaFrozen; do
  touch "$OUTPUT_ROOT/$run/Precip_hourly_WRF_${region}_T13_T36_InitUTC_2026-11-24_00_00_combined_overview_4x6_grid.png"
done
if commit_rc=7 bash "$root/publish_worknx_ningxia_to_github.sh" --run "$run"; then exit 1; fi
[[ ! -e "$OUTPUT_ROOT/$run/supercooled/.published-sha256" ]]
: > "$calls"
bash "$root/publish_worknx_ningxia_to_github.sh" --run "$run"
[[ $(grep -c '^1 ' "$calls") == 1 && $(grep -c '^0 ' "$calls") == 3 ]]
[[ -s "$OUTPUT_ROOT/$run/supercooled/.published-sha256" ]]
echo 'PASS: independent Ningxia staging, failed diagnostic isolation, single commit, receipt after success'
