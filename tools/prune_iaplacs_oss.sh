#!/usr/bin/env bash

set -Eeuo pipefail

MODE="${1:---dry-run}"
case "$MODE" in
	--dry-run|--apply) ;;
	*)
		echo "Usage: $0 [--dry-run|--apply]" >&2
		exit 2
		;;
esac

IAPLACS_OSS_ENV_FILE="${IAPLACS_OSS_ENV_FILE:-$HOME/.iaplacs-oss.env}"
if [ ! -r "$IAPLACS_OSS_ENV_FILE" ]; then
	echo "ERROR: OSS runtime settings not found: $IAPLACS_OSS_ENV_FILE" >&2
	exit 1
fi

set -a
. "$IAPLACS_OSS_ENV_FILE"
set +a

: "${IAPLACS_OSS_BUCKET:?missing IAPLACS_OSS_BUCKET}"
: "${IAPLACS_OSS_ENDPOINT:?missing IAPLACS_OSS_ENDPOINT}"

OSSUTIL_BIN="${IAPLACS_OSSUTIL_BIN:-$HOME/bin/ossutil}"
RETAIN_RUNS="${IAPLACS_OSS_RETAIN_RUNS:-5}"
OBJECT_PREFIX="${IAPLACS_OSS_PREFIX:-}"

if [ ! -x "$OSSUTIL_BIN" ]; then
	echo "ERROR: ossutil not found or not executable: $OSSUTIL_BIN" >&2
	exit 1
fi
if [[ ! "$RETAIN_RUNS" =~ ^[1-9][0-9]*$ ]]; then
	echo "ERROR: IAPLACS_OSS_RETAIN_RUNS must be a positive integer" >&2
	exit 1
fi

OBJECT_PREFIX="${OBJECT_PREFIX#/}"
OBJECT_PREFIX="${OBJECT_PREFIX%/}"
if [ -n "$OBJECT_PREFIX" ]; then
	MAPS_PREFIX="$OBJECT_PREFIX/data/current/maps"
else
	MAPS_PREFIX="data/current/maps"
fi

TMP_LIST="$(mktemp /tmp/iaplacs_oss_list.XXXXXX)"
TMP_INVENTORY="$(mktemp /tmp/iaplacs_oss_inventory.XXXXXX)"
TMP_RUNS="$(mktemp /tmp/iaplacs_oss_runs.XXXXXX)"
trap 'rm -f "$TMP_LIST" "$TMP_INVENTORY" "$TMP_RUNS"' EXIT

"$OSSUTIL_BIN" ls "oss://${IAPLACS_OSS_BUCKET}/${MAPS_PREFIX}/" \
	-e "$IAPLACS_OSS_ENDPOINT" > "$TMP_LIST"

while read -r _date _time _offset _zone size _storage _etag object_url; do
	case "$object_url" in
		oss://*/"$MAPS_PREFIX"/worknx_summary_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9]/*)
			relative="${object_url#*"/$MAPS_PREFIX/"}"
			run_dir="${relative%%/*}"
			run_prefix="${run_dir#worknx_summary_}"
			printf 'worknx_summary\t%s\t%s\t%s\n' "$run_prefix" "$size" "$object_url" >> "$TMP_INVENTORY"
			;;
		oss://*/"$MAPS_PREFIX"/workxj_summary_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9]/*)
			relative="${object_url#*"/$MAPS_PREFIX/"}"
			run_dir="${relative%%/*}"
			run_prefix="${run_dir#workxj_summary_}"
			printf 'workxj_summary\t%s\t%s\t%s\n' "$run_prefix" "$size" "$object_url" >> "$TMP_INVENTORY"
			;;
		oss://*/"$MAPS_PREFIX"/wrf_montage_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9]/*)
			relative="${object_url#*"/$MAPS_PREFIX/"}"
			run_dir="${relative%%/*}"
			run_prefix="${run_dir#wrf_montage_}"
			printf 'wrf_montage\t%s\t%s\t%s\n' "$run_prefix" "$size" "$object_url" >> "$TMP_INVENTORY"
			;;
	esac
done < "$TMP_LIST"

if [ ! -s "$TMP_INVENTORY" ]; then
	echo "ERROR: no recognized forecast objects found under oss://${IAPLACS_OSS_BUCKET}/${MAPS_PREFIX}/" >&2
	exit 1
fi

deleted_runs=0
deleted_objects=0
deleted_bytes=0

for family in worknx_summary workxj_summary wrf_montage; do
	awk -F '\t' -v family="$family" '$1 == family {print $2}' "$TMP_INVENTORY" | sort -ru > "$TMP_RUNS"
	all_runs=()
	while IFS= read -r run_prefix; do
		[ -n "$run_prefix" ] && all_runs+=("$run_prefix")
	done < "$TMP_RUNS"

	echo "OSS retention family=$family retain=$RETAIN_RUNS found=${#all_runs[@]}"
	if [ "${#all_runs[@]}" -gt 0 ]; then
		printf '  keep: %s\n' "${all_runs[@]:0:RETAIN_RUNS}"
	fi

	if [ "${#all_runs[@]}" -le "$RETAIN_RUNS" ]; then
		echo "  delete: none"
		continue
	fi

	for run_prefix in "${all_runs[@]:RETAIN_RUNS}"; do
		object_count="$(awk -F '\t' -v family="$family" -v run="$run_prefix" '$1 == family && $2 == run {count++} END {print count + 0}' "$TMP_INVENTORY")"
		object_bytes="$(awk -F '\t' -v family="$family" -v run="$run_prefix" '$1 == family && $2 == run {sum += $3} END {printf "%.0f", sum + 0}' "$TMP_INVENTORY")"
		cloud_prefix="oss://${IAPLACS_OSS_BUCKET}/${MAPS_PREFIX}/${family}_${run_prefix}/"
		echo "  delete: run=$run_prefix objects=$object_count bytes=$object_bytes prefix=$cloud_prefix"

		if [ "$MODE" = "--apply" ]; then
			"$OSSUTIL_BIN" rm "$cloud_prefix" -r -f -e "$IAPLACS_OSS_ENDPOINT"
		fi
		deleted_runs=$((deleted_runs + 1))
		deleted_objects=$((deleted_objects + object_count))
		deleted_bytes=$((deleted_bytes + object_bytes))
	done
done

if [ "$MODE" = "--dry-run" ]; then
	echo "Dry run only: candidate_runs=$deleted_runs candidate_objects=$deleted_objects candidate_bytes=$deleted_bytes"
else
	echo "Retention applied: deleted_runs=$deleted_runs deleted_objects=$deleted_objects deleted_bytes=$deleted_bytes"
fi
