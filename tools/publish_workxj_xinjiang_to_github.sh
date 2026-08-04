#!/usr/bin/env bash

# Xinjiang service adapter for the shared regional render and publication path.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export WORK_NX_ROOT="${WORK_XJ_ROOT:-/data1/elpt_2022_00083/zhoubj/WORK_xj}"
export OUTPUT_ROOT="${OUTPUT_ROOT:-$SCRIPT_DIR/workxj_xinjiang_overview}"
export SERVICE_LABEL="Xinjiang"
export SERVICE_FILE_TOKEN="Xinjiang"
export REGION_MODE="xinjiang"
export PUBLISH_FAMILY="workxj_summary"
export SOURCE_LABEL="WORK_xj"
export NINGXIA_PROVINCE_SHP_FILE="${XINJIANG_PROVINCE_SHP_FILE:-$SCRIPT_DIR/SHP/省界_region.shp}"
export NINGXIA_COUNTY_SHP_FILE="${XINJIANG_CITY_SHP_FILE:-}"

exec "$SCRIPT_DIR/publish_worknx_ningxia_to_github.sh" "$@"
