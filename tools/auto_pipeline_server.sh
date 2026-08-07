#!/usr/bin/env bash

set -Eeuo pipefail

if [ -n "${WEBSITE_DIR:-}" ]; then
	SCRIPT_DIR="$WEBSITE_DIR"
elif [ -n "${SLURM_SUBMIT_DIR:-}" ] && [ -f "$SLURM_SUBMIT_DIR/rain_wrf_hour_bjt.ncl" ]; then
	SCRIPT_DIR="$SLURM_SUBMIT_DIR"
else
	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
cd "$SCRIPT_DIR"

HOME_DIR="${IAP_HOME_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
WORK_ROOT="${WORK_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"
STATE_DIR="${STATE_DIR:-$SCRIPT_DIR/state}"
LAST_SOURCE_STATE_FILE="${LAST_SOURCE_STATE_FILE:-$STATE_DIR/wrf_pipeline_last_rendered.state}"
MIN_WRFOUT_BYTES="${MIN_WRFOUT_BYTES:-8000000000}"
MIN_FILE_AGE_SECONDS="${MIN_FILE_AGE_SECONDS:-1200}"
MIN_TIME_COUNT="${MIN_TIME_COUNT:-14}"
mkdir -p "$LOG_DIR" "$STATE_DIR" wrf_hourly_png shangrao_hail_hourly_png

RUN_STAMP="$(date +%Y%m%d_%H%M%S)"
exec > >(tee -a "$LOG_DIR/pipeline_${RUN_STAMP}.log") 2>&1

echo "================================================================"
echo "WRF Website pipeline started at $(date)"
echo "Working directory: $SCRIPT_DIR"
echo "IAP home directory: $HOME_DIR"
echo "Slurm submit directory: ${SLURM_SUBMIT_DIR:-unset}"
echo "Host: $(hostname)"
echo "================================================================"

# Cluster profile scripts reference interactive-shell variables that Slurm and
# cron do not define.  Disable nounset only while loading that environment.
set +u
if [ -f /etc/profile ]; then
	# shellcheck source=/dev/null
	if ! source /etc/profile; then
		echo "WARNING: /etc/profile returned a non-zero status" >&2
	fi
fi

if [ -f "$HOME_DIR/.bashrc.minkerui" ]; then
	# shellcheck source=/dev/null
	if ! source "$HOME_DIR/.bashrc.minkerui"; then
		echo "WARNING: $HOME_DIR/.bashrc.minkerui returned a non-zero status" >&2
	fi
fi
set -u
cd "$SCRIPT_DIR"

for cmd in ncks ncl montage convert python; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "ERROR: required command not found: $cmd" >&2
		exit 127
	fi
done

if [ ! -f "$SCRIPT_DIR/rain_wrf_hour_bjt.ncl" ]; then
	echo "ERROR: missing rain_wrf_hour_bjt.ncl in $SCRIPT_DIR" >&2
	exit 1
fi
if [ ! -f "$SCRIPT_DIR/rain_worknx_national_hour_bjt.ncl" ]; then
	echo "ERROR: missing rain_worknx_national_hour_bjt.ncl in $SCRIPT_DIR" >&2
	exit 1
fi

if [ ! -x "$SCRIPT_DIR/make_wrf_montages.sh" ]; then
	echo "ERROR: missing executable make_wrf_montages.sh in $SCRIPT_DIR" >&2
	exit 1
fi

wrf_completed_successfully() {
	local candidate="$1" rsl_file
	rsl_file="$(dirname "$candidate")/rsl.error.0000"
	[ -f "$rsl_file" ] && tail -n 200 "$rsl_file" | grep -q 'SUCCESS COMPLETE WRF'
}

latest_publishable_wrf() {
	local candidate time_count candidate_size candidate_mtime now_epoch
	now_epoch="$(date +%s)"
	while IFS= read -r candidate; do
		time_count="$(ncks -m -v Times "$candidate" 2>/dev/null | awk '/Time = UNLIMITED/ && !seen { gsub(/[^0-9]/, "", $0); print; seen=1 }')"
		[[ "$time_count" =~ ^[0-9]+$ ]] && (( time_count >= MIN_TIME_COUNT )) || continue
		candidate_size="$(stat -c '%s' "$candidate")"
		(( candidate_size >= MIN_WRFOUT_BYTES )) || continue
		if ! wrf_completed_successfully "$candidate"; then
			candidate_mtime="$(stat -c '%Y' "$candidate")"
			(( now_epoch - candidate_mtime >= MIN_FILE_AGE_SECONDS )) || continue
		fi
		printf '%s\n' "$candidate"
		return 0
	done < <(find "$WORK_ROOT" -mindepth 4 -maxdepth 4 -type f -name 'wrfout_d01_*' -printf '%p\n' | sort -r)
	return 1
}

SOURCE_WRF="$(latest_publishable_wrf || true)"
if [ -z "$SOURCE_WRF" ]; then
	echo "No publishable WORK wrfout available; defer publication."
	exit 0
fi

source_base="$(basename "$SOURCE_WRF")"
if [[ ! "$source_base" =~ ^wrfout_d01_([0-9]{4})-([0-9]{2})-([0-9]{2})_([0-9]{2}):00:00$ ]]; then
	echo "ERROR: cannot parse WRF start time: $SOURCE_WRF" >&2
	exit 1
fi
source_date="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
source_hour="${BASH_REMATCH[4]}"
COMPACT_WRF="$SCRIPT_DIR/wrfout_d01_${source_date}_${source_hour}_rain_vars.nc"
TIME_COUNT="$(ncks -m -v Times "$SOURCE_WRF" 2>/dev/null | awk '/Time = UNLIMITED/ && !seen { gsub(/[^0-9]/, "", $0); print; seen=1 }')"
if ! [[ "$TIME_COUNT" =~ ^[0-9]+$ ]] || (( TIME_COUNT < MIN_TIME_COUNT )); then
	echo "ERROR: cannot determine a usable T13 lead from $SOURCE_WRF" >&2
	exit 1
fi
LAST_LEAD=$((TIME_COUNT - 1))
SOURCE_STATE="${SOURCE_WRF}:$(stat -c '%s' "$SOURCE_WRF"):$(stat -c '%Y' "$SOURCE_WRF"):${TIME_COUNT}"
if [ "${IAPLACS_FORCE_RENDER:-0}" != "1" ] && [ -f "$LAST_SOURCE_STATE_FILE" ] && [ "$(tr -d '[:space:]' < "$LAST_SOURCE_STATE_FILE")" = "$SOURCE_STATE" ]; then
	echo "Selected WORK WRF is unchanged; skip redraw: $SOURCE_STATE"
	exit 0
fi

echo "Extracting publishable WORK WRF through T${LAST_LEAD}: $SOURCE_WRF"
rm -f "$SCRIPT_DIR"/wrfout_d01_*_rain_vars.nc
PRECIP_VARIABLES="Times,XLAT,XLONG,RAINNC,RAINC"
for optional_variable in GRAUPELNC HAILNC; do
	if ncks -m -v "$optional_variable" "$SOURCE_WRF" >/dev/null 2>&1; then
		PRECIP_VARIABLES+=",${optional_variable}"
	fi
done
echo "Extracting precipitation variables: $PRECIP_VARIABLES"
ncks -O -v "$PRECIP_VARIABLES" "$SOURCE_WRF" "$COMPACT_WRF"

wrf_to_bjt_prefix() {
	local ymd="$1"
	local hour="$2"
	python - "$ymd" "$hour" <<'PY'
from __future__ import print_function
import sys
from datetime import datetime, timedelta

dt = datetime.strptime(sys.argv[1] + sys.argv[2], "%Y%m%d%H") + timedelta(hours=8)
print(dt.strftime("%Y%m%d_%H"))
PY
}

format_bjt_interval() {
	local start="$1" end="$2"
	printf '%s-%s-%s %s:00 - %s-%s-%s %s:00 BJT' \
		"${start:0:4}" "${start:4:2}" "${start:6:2}" "${start:8:2}" \
		"${end:0:4}" "${end:4:2}" "${end:6:2}" "${end:8:2}"
}

caption_accumulation() {
	local source_path="$1" output_path="$2" hours="$3" start="$4" end="$5" interval
	interval="$(format_bjt_interval "$start" "$end")"

	convert "$source_path" \
		-trim +repage \
		-bordercolor white \
		-border 20 \
		-gravity North \
		-background white \
		-splice 0x112 \
		-fill black \
		-font Times-Bold \
		-stroke black \
		-strokewidth 1 \
		-pointsize 34 \
		-annotate +0+10 "${hours} h Accumulated Precipitation\n${interval}" \
		"$output_path"
}

BJT_PREFIX="$(wrf_to_bjt_prefix "$source_date" "$source_hour")"
rm -f "$SCRIPT_DIR"/wrf_hourly_png/"${BJT_PREFIX}"_combined_overview_*_grid.png \
		"$SCRIPT_DIR"/wrf_hourly_png/"${BJT_PREFIX}"_combined_detail_p*_4x3_grid.png \
		"$SCRIPT_DIR"/wrf_hourly_png/"${BJT_PREFIX}"_combined_hail_warning_*_grid.png \
		"$SCRIPT_DIR"/wrf_hourly_png/"${BJT_PREFIX}"_national_accum_* \
		"$SCRIPT_DIR"/wrf_hourly_png/"${BJT_PREFIX}"_combined_accum_*

echo "Running NCL hourly rainfall plotting for $BJT_PREFIX..."
RAIN_COMPONENT_MODE=total ncl "$SCRIPT_DIR/rain_wrf_hour_bjt.ncl"
echo "Running NCL Shangrao hail-warning plotting for $BJT_PREFIX..."
HAIL_PNG_DIR="$SCRIPT_DIR/shangrao_hail_hourly_png"
rm -f "$HAIL_PNG_DIR/${BJT_PREFIX}_rain_hour_"*_BJT.png \
  "$HAIL_PNG_DIR/${BJT_PREFIX}_combined_"*_grid.png \
  "$HAIL_PNG_DIR/${BJT_PREFIX}_shangrao_hail_warning_rain_hour_"*_BJT.png \
  "$HAIL_PNG_DIR/${BJT_PREFIX}_shangrao_hail_warning_combined_"*_grid.png
WORK_NX_WRF_DIR="$SCRIPT_DIR" \
  WORK_NX_NATIONAL_PNG_DIR="$HAIL_PNG_DIR" \
  WORK_NX_NATIONAL_PROVINCE_SHP_FILE="$SCRIPT_DIR/SHP/省界_region.shp" \
  RAIN_COMPONENT_MODE=frozen \
  RAIN_OUTPUT_AREA=shangrao_hail_warning \
  ncl "$SCRIPT_DIR/rain_worknx_national_hour_bjt.ncl"
bash "$SCRIPT_DIR/make_wrf_montages.sh" "$HAIL_PNG_DIR" "${BJT_PREFIX}_shangrao_hail_warning"
HAIL_OVERVIEW="$(ls -t "$HAIL_PNG_DIR/${BJT_PREFIX}_shangrao_hail_warning_combined_overview_"*_grid.png 2>/dev/null | head -n 1 || true)"
if [ -z "$HAIL_OVERVIEW" ]; then
	echo "ERROR: Shangrao hail-warning overview was not generated for $BJT_PREFIX" >&2
	exit 1
fi
hail_name="$(basename "$HAIL_OVERVIEW")"
hail_target="${hail_name/${BJT_PREFIX}_shangrao_hail_warning_combined_overview_/${BJT_PREFIX}_combined_hail_warning_}"
cp -f "$HAIL_OVERVIEW" "$SCRIPT_DIR/wrf_hourly_png/$hail_target"
echo "Running NCL nationwide hourly rainfall plotting for $BJT_PREFIX..."
NATIONAL_PNG_DIR="$SCRIPT_DIR/national_hourly_png"
mkdir -p "$NATIONAL_PNG_DIR"
rm -f "$NATIONAL_PNG_DIR/${BJT_PREFIX}_national_rain_hour_"*_BJT.png \
	"$NATIONAL_PNG_DIR/${BJT_PREFIX}_national_combined_"*_grid.png
WORK_NX_WRF_DIR="$SCRIPT_DIR" \
	WORK_NX_NATIONAL_PNG_DIR="$NATIONAL_PNG_DIR" \
	WORK_NX_NATIONAL_PROVINCE_SHP_FILE="$SCRIPT_DIR/SHP/省界_region.shp" \
	ncl "$SCRIPT_DIR/rain_worknx_national_hour_bjt.ncl"
bash "$SCRIPT_DIR/make_wrf_montages.sh" "$NATIONAL_PNG_DIR" "${BJT_PREFIX}_national"
NATIONAL_OVERVIEW="$(ls -t "$NATIONAL_PNG_DIR/${BJT_PREFIX}_national_combined_overview_"*_grid.png 2>/dev/null | head -n 1 || true)"
if [ -n "$NATIONAL_OVERVIEW" ]; then
	national_name="$(basename "$NATIONAL_OVERVIEW")"
	national_target="${national_name/${BJT_PREFIX}_national_combined_overview_/${BJT_PREFIX}_combined_national_}"
	cp -f "$NATIONAL_OVERVIEW" "$SCRIPT_DIR/wrf_hourly_png/$national_target"
fi
echo "Running NCL accumulated rainfall plotting after T13 spin-up..."
for accum_hours in 12 24; do
	RAIN_ACCUM_HOURS="$accum_hours" \
		WORK_NX_WRF_DIR="$SCRIPT_DIR" \
		WORK_NX_NATIONAL_PNG_DIR="$SCRIPT_DIR/wrf_hourly_png" \
		WORK_NX_NATIONAL_PROVINCE_SHP_FILE="$SCRIPT_DIR/SHP/省界_region.shp" \
		ncl "$SCRIPT_DIR/rain_worknx_national_hour_bjt.ncl"
	for image in "$SCRIPT_DIR"/wrf_hourly_png/"${BJT_PREFIX}"_national_accum_"${accum_hours}"h_*_BJT.png; do
		[ -e "$image" ] || continue
		name="$(basename "$image")"
		target="${name/_national_accum_/_combined_accum_}"
		target="${target%.png}_grid.png"
		if [[ ! "$name" =~ _national_accum_([0-9]{2})h_([0-9]{10})-([0-9]{10})_BJT\.png$ ]]; then
			echo "ERROR: cannot parse BJT accumulation interval from $image" >&2
			exit 1
		fi
		caption_accumulation "$image" "$SCRIPT_DIR/wrf_hourly_png/$target" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
	done
done

echo "Building T13-T${LAST_LEAD} montage for $BJT_PREFIX"
bash "$SCRIPT_DIR/make_wrf_montages.sh" "$SCRIPT_DIR/wrf_hourly_png" "$BJT_PREFIX"
printf '%s\n' "$BJT_PREFIX" > "$SCRIPT_DIR/latest_wrf_prefixes.txt"

LATEST_OVERVIEW="$(ls -t "$SCRIPT_DIR"/wrf_hourly_png/"${BJT_PREFIX}"_combined_overview_*_grid.png 2>/dev/null | head -n 1 || true)"
if [ -n "$LATEST_OVERVIEW" ]; then
	LATEST_PREFIX="$(basename "$LATEST_OVERVIEW" | sed -E 's/_combined_overview_.*_grid\.png$//')"
	{
		echo "latest_prefix=$LATEST_PREFIX"
		echo "updated_at=$(date '+%Y-%m-%d %H:%M:%S %Z')"
		echo "overview=wrf_hourly_png/$(basename "$LATEST_OVERVIEW")"
		for img in "$SCRIPT_DIR"/wrf_hourly_png/"${LATEST_PREFIX}"_combined_detail_p*_4x3_grid.png; do
			[ -e "$img" ] || continue
			echo "detail=wrf_hourly_png/$(basename "$img")"
		done
	} > "$SCRIPT_DIR/latest_wrf_outputs.txt"
fi

echo "================================================================"
echo "WRF Website pipeline finished at $(date)"
echo "Outputs are under: $SCRIPT_DIR/wrf_hourly_png"
echo "================================================================"
printf '%s\n' "$SOURCE_STATE" > "$LAST_SOURCE_STATE_FILE"
