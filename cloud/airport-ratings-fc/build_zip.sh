#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")" && pwd)
dist_dir="$root_dir/dist"

mkdir -p "$dist_dir"
rm -f "$dist_dir/airport-ratings-fc.zip"
(cd "$root_dir" && zip -q "$dist_dir/airport-ratings-fc.zip" index.py)
echo "$dist_dir/airport-ratings-fc.zip"
