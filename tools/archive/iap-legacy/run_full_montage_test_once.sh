#!/usr/bin/env bash

# Preserve the legacy runtime root when launched from the organized directory.
if [[ -L "$(dirname "${BASH_SOURCE[0]}")/.runtime-root" ]]; then
  exec bash "$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.runtime-root" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@"
fi

set -Eeuo pipefail

HOME_DIR="${HOME_DIR:-/data1/elpt_2022_00083/kerui}"
cd "$HOME_DIR/Website"

src="$(ls -t "$HOME_DIR"/wrfout_d01_*_rain_vars.nc 2>/dev/null | head -n 1 || true)"
if [ -z "$src" ]; then
	echo "ERROR: no source wrfout_d01_*_rain_vars.nc found in $HOME_DIR" >&2
	exit 1
fi

stamp="$(date +%Y%m%d_%H%M%S)"
test_root="$HOME_DIR/Website/manual_test_montage_${stamp}"
mkdir -p "$test_root/logs" "$test_root/wrf_hourly_png"
ln -s ../SHP "$test_root/SHP"
ln -s "$src" "$test_root/$(basename "$src")"

base="$(basename "$src")"
ymd="$(echo "$base" | sed -E 's/^wrfout_d01_([0-9]{8})_[0-9]{2}_rain_vars\.nc$/\1/')"
hour="$(echo "$base" | sed -E 's/^wrfout_d01_[0-9]{8}_([0-9]{2})_rain_vars\.nc$/\1/')"
prefix="$(
	python - "$ymd" "$hour" <<'PY'
from __future__ import print_function
import sys
from datetime import datetime, timedelta
dt = datetime.strptime(sys.argv[1] + sys.argv[2], "%Y%m%d%H") + timedelta(hours=8)
print(dt.strftime("%Y%m%d_%H"))
PY
)"

jobid="$(
	sbatch --parsable \
		--job-name=wrf_montage_test \
		--partition=cpu_single \
		--time=01:00:00 \
		--nodes=1 \
		--ntasks=1 \
		--cpus-per-task=1 \
		--mem=4G \
		--chdir="$test_root" \
		--output="$test_root/logs/slurm-%x-%j.out" \
		--error="$test_root/logs/slurm-%x-%j.err" \
		--wrap="bash -lc 'source ~/.bashrc.minkerui; cd \"$test_root\"; ncl ../rain_wrf_hour_bjt.ncl; bash ../make_wrf_montages.sh wrf_hourly_png \"$prefix\"'"
)"

echo "source=$src"
echo "prefix=$prefix"
echo "test_root=$test_root"
echo "jobid=$jobid"

for _ in $(seq 1 180); do
	if ! squeue -h -j "$jobid" | grep -q .; then
		break
	fi
	sleep 10
done

if squeue -h -j "$jobid" | grep -q .; then
	echo "ERROR: test job still running after wait, cancelling $jobid" >&2
	scancel "$jobid"
	exit 2
fi

echo "--- stdout tail ---"
tail -n 80 "$test_root/logs/slurm-wrf_montage_test-${jobid}.out" 2>/dev/null || true
echo "--- stderr tail ---"
tail -n 80 "$test_root/logs/slurm-wrf_montage_test-${jobid}.err" 2>/dev/null || true
echo "--- outputs ---"
find "$test_root/wrf_hourly_png" -maxdepth 1 -type f -name "${prefix}*.png" -printf '%f %s bytes\n' | sort
