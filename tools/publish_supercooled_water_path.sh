#!/usr/bin/env bash
# Disabled by default. Rendering and scientific validation require a plot job.
set -Eeuo pipefail
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_PATH"
[[ ! -L "$SCRIPT_PATH/.runtime-root" ]] || ROOT="$(cd -P "$SCRIPT_PATH/.runtime-root" && pwd)"
source "$SCRIPT_PATH/supercooled_settings.sh"
original_args=("$@")
run=""; profile=""; render_only=0; output=""; ensure_public=0
while (( $# )); do
  case "$1" in
    --run) run="${2:-}"; shift 2 ;;
    --profile) profile="${2:-}"; shift 2 ;;
    --render-only) render_only=1; shift ;;
    --output) output="${2:-}"; shift 2 ;;
    --ensure-public) ensure_public=1; shift ;;
    *) echo "Unsupported argument: $1" >&2; exit 64 ;;
  esac
done
[[ "$run" =~ ^[0-9]{8}_[0-9]{2}$ ]] || exit 64
case "$profile" in
  ningxia) model=WORK; family=worknx_summary; folder=worknx_ningxia_overview; city=ningxia_city_county ;;
  yunnan) model=WORK_yn; family=airport_yunnan; folder=worknx_yunnan_airports_overview; city=yunnan_city ;;
  xinjiang) model=WORK_xj; family=workxj_summary; folder=workxj_xinjiang_overview; city="" ;;
  *) exit 64 ;;
esac
if (( ! render_only )) && ! iaplacs_supercooled_enabled "$ROOT" "$run"; then
  echo "Supercooled products disabled for $run; no job or upload started"
  exit 0
fi
if (( render_only )) && [[ -z "$output" ]]; then
  echo "--render-only requires an explicit isolated --output directory" >&2
  exit 64
fi
source "$SCRIPT_PATH/runtime_paths.sh" "${original_args[@]}"
PYTHON_BIN="${PYTHON_BIN:-/public/software/apps/conda/latest/bin/python3}"
model_root="${SUPERCOOLED_MODEL_ROOT:-/data1/elpt_2022_00083/zhoubj/$model}"
wrf_dir="$model_root/${run/_/}/gfs/wrf"
if [[ ! -f "$wrf_dir/rsl.error.0000" ]] || ! tail -n 200 "$wrf_dir/rsl.error.0000" | grep -q 'SUCCESS COMPLETE WRF'; then
  echo "Supercooled $profile $run: waiting for WRF completion"
  exit 75
fi
output="${output:-$ROOT/$folder/$run/supercooled}"
mkdir -p "$output"
exec 7>"$output/.render.lock"
flock -n 7 || exit 75
input="$wrf_dir/wrfout_d01_${run:0:4}-${run:4:2}-${run:6:2}_${run:9:2}:00:00"
map_args=(--province-shp "$ROOT/SHP/省界_region.shp")
[[ -z "$city" ]] || map_args+=(--city-shp "$ROOT/SHP/$city.shp")
"$PYTHON_BIN" "$SCRIPT_PATH/render_supercooled_water_path.py" --input "$input" \
  --output "$output" --profile "$profile" --run "$run" "${map_args[@]}"
(( ! render_only )) || { echo "Render-only complete; nothing published"; exit 0; }
digest="$(sha256sum "$output/production_manifest.json" | awk '{print $1}')"
receipt="$output/.published-sha256"
if [[ -f "$receipt" && "$(<"$receipt")" == "$digest" ]] && (( ! ensure_public )); then
  echo "Supercooled $profile $run already published"
  exit 0
fi
generation="$(PYTHONPATH="$SCRIPT_PATH${PYTHONPATH:+:$PYTHONPATH}" "$PYTHON_BIN" - "$output" <<'PY'
import json
import sys
from pathlib import Path
from supercooled_contract import validate_manifest
root = Path(sys.argv[1])
manifest = json.loads((root / "production_manifest.json").read_text(encoding="utf-8"))
validate_manifest(manifest, root)
print(manifest["generation"])
PY
)"
[[ "$generation" =~ ^[a-f0-9]{20}$ ]] || exit 65
upload="$(mktemp -d "$output/.upload.XXXXXX")"
trap 'rm -rf -- "$upload"' EXIT
cp "$output/production_manifest.json" "$upload/"
cp -a "$output/$generation" "$upload/"
bash "$SCRIPT_PATH/publish_airport_aviation_to_oss.sh" \
  --family "$family" --run-prefix "$run" --supercooled-dir "$upload"
printf '%s\n' "$digest" > "$receipt.tmp.$$"
mv "$receipt.tmp.$$" "$receipt"
echo "Supercooled $profile $run published"
