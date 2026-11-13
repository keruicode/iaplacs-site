#!/usr/bin/env bash
set -Eeuo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
export SUPERCOOLED_START_FILE="$root/.tmp/nonexistent-supercooled-test-$$"
for profile in ningxia yunnan xinjiang; do
  result="$(bash "$root/tools/publish_supercooled_water_path.sh" --profile "$profile" --run 20261112_18)"
  [[ "$result" == *'disabled'* ]]
done
echo 'Disabled publishers return before scheduler, Python, WRF reads and network'
