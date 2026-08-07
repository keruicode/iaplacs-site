#!/usr/bin/env bash

set -u

PNG_DIR="${1:-wrf_hourly_png}"
PREFIX_FILTER="${2:-${PREFIX_FILTER:-}}"
DETAIL_TILE="${DETAIL_TILE:-4x3}"
OVERVIEW_COLS="${OVERVIEW_COLS:-6}"
MONTAGE_GEOMETRY="${MONTAGE_GEOMETRY:-100%x100%+2+2}"
MONTAGE_BACKGROUND="${MONTAGE_BACKGROUND:-white}"

if ! command -v montage >/dev/null 2>&1; then
	echo "ERROR: ImageMagick montage command not found." >&2
	exit 127
fi
if ! command -v convert >/dev/null 2>&1; then
	echo "ERROR: ImageMagick convert command not found." >&2
	exit 127
fi

if [ ! -d "$PNG_DIR" ]; then
	echo "ERROR: PNG directory not found: $PNG_DIR" >&2
	exit 1
fi

case "$DETAIL_TILE" in
	*x*) ;;
	*)
		echo "ERROR: DETAIL_TILE must look like 4x3, got: $DETAIL_TILE" >&2
		exit 1
		;;
esac

DETAIL_COLS="${DETAIL_TILE%x*}"
DETAIL_ROWS="${DETAIL_TILE#*x}"
DETAIL_PAGE_SIZE=$((DETAIL_COLS * DETAIL_ROWS))

if [ "$DETAIL_PAGE_SIZE" -le 0 ]; then
	echo "ERROR: DETAIL_TILE produced invalid page size: $DETAIL_TILE" >&2
	exit 1
fi

cd "$PNG_DIR" || exit 1
shopt -s nullglob

prefixes=$(
	for img in *_rain_hour_*_BJT.png; do
		printf '%s\n' "${img%%_rain_hour_*}"
	done | sort -u
)

if [ -z "$prefixes" ]; then
	echo "No hourly WRF PNG files found in $PNG_DIR."
	exit 0
fi

status=0

caption_national_panel() {
  local panel_path="$1" caption_dir="$2" caption_path
  caption_path="$caption_dir/$(basename "$panel_path")"

  # National NCL panels already render the valid BJT interval. The montage
  # builder only crops their canvas, otherwise every panel gets two titles.
  convert "$panel_path" -trim +repage "$caption_path"
}

add_national_header() {
	local mosaic_path="$1" overview_path="$2" prefix="$3" init_label
	if [[ "$prefix" =~ ^([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})(_.+)?$ ]]; then
		init_label="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:00 BJT"
	else
		init_label="BJT"
	fi
	convert "$mosaic_path" \
		-gravity North \
		-background white \
		-splice 0x160 \
		-fill black \
		-font Times-Bold \
		-stroke black \
		-strokewidth 1 \
		-pointsize 132 \
		-annotate +0+24 "Forecast Initialization: $init_label" \
		"$overview_path"
}

while IFS= read -r prefix; do
	[ -n "$prefix" ] || continue

	if [ -n "$PREFIX_FILTER" ] && [[ "$prefix" != $PREFIX_FILTER ]]; then
		continue
	fi

	images=("${prefix}"_rain_hour_*_BJT.png)
	count=${#images[@]}

	if [ "$count" -eq 0 ]; then
		continue
	fi
	if [ "$count" -eq 0 ]; then
		continue
	fi

	overview_rows=$(((count + OVERVIEW_COLS - 1) / OVERVIEW_COLS))
	overview_tile="${OVERVIEW_COLS}x${overview_rows}"
	overview_out="${prefix}_combined_overview_${overview_tile}_grid.png"
	overview_mosaic=".${overview_out}.mosaic.png"
	montage_images=("${images[@]}")
	detail_images=("${images[@]}")
	if [[ "$prefix" == *_national || "$prefix" == *_hail_warning ]]; then
		caption_dir=".${prefix}_captioned"
		mkdir -p "$caption_dir"
		montage_images=()
		for image in "${images[@]}"; do
			caption_national_panel "$image" "$caption_dir" || { status=1; break; }
			montage_images+=("$caption_dir/$(basename "$image")")
		done
		[ "$status" -eq 0 ] || continue
		detail_images=("${montage_images[@]}")
	fi

	echo "Building ${overview_out} from ${count} T13+ panels..."
	if ! montage "${montage_images[@]}" -tile "$overview_tile" -geometry "$MONTAGE_GEOMETRY" -background "$MONTAGE_BACKGROUND" "$overview_mosaic"; then
		echo "ERROR: failed to build $overview_out" >&2
		status=1
		continue
	fi
	if [[ "$prefix" == *_national || "$prefix" == *_hail_warning ]]; then
		add_national_header "$overview_mosaic" "$overview_out" "$prefix"
		rm -f "$overview_mosaic"
	else
		mv -f "$overview_mosaic" "$overview_out"
	fi

	pages=$(((count + DETAIL_PAGE_SIZE - 1) / DETAIL_PAGE_SIZE))
	page=1
	idx=0

	while [ "$idx" -lt "$count" ]; do
		page_images=()
		end=$((idx + DETAIL_PAGE_SIZE))
		if [ "$end" -gt "$count" ]; then
			end="$count"
		fi

		j="$idx"
		while [ "$j" -lt "$end" ]; do
			page_images+=("${detail_images[$j]}")
			j=$((j + 1))
		done

		page_out=$(printf '%s_combined_detail_p%02d_%s_grid.png' "$prefix" "$page" "$DETAIL_TILE")
		echo "Building ${page_out} (${page}/${pages})..."
		if ! montage "${page_images[@]}" -tile "$DETAIL_TILE" -geometry "$MONTAGE_GEOMETRY" -background "$MONTAGE_BACKGROUND" "$page_out"; then
			echo "ERROR: failed to build $page_out" >&2
			status=1
			break
		fi

		idx="$end"
		page=$((page + 1))
	done
done <<< "$prefixes"

exit "$status"
