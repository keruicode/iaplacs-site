#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/plot_scheduler.sh"
iaplacs_require_compute || exit 77
