#!/usr/bin/env bash
# Submit this preflight as a plot job; never import scientific libraries on login.
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/runtime_paths.sh"
export PYTHONPATH="$IAPLACS_SCRIPT_DIR${PYTHONPATH:+:$PYTHONPATH}"
"${PYTHON_BIN:-/public/software/apps/conda/latest/bin/python3}" - <<'PY'
import os
from pathlib import Path

import numpy as np
from netCDF4 import Dataset
from PIL import Image
import render_regional_visibility
import render_yunnan_radar
import render_yunnan_airport_aviation_preview

for name in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS"):
    assert os.environ[name] == "1", name
np.dot(np.ones((8, 8)), np.ones((8, 8)))
for line in Path("/proc/self/status").read_text().splitlines():
    if line.startswith("Threads:"):
        print(line)
        assert int(line.split()[1]) <= int(os.environ.get("SLURM_CPUS_PER_TASK", "2")), line
print("Scientific imports and thread check passed; no forecast data read.")
PY
"${NCL_BIN:-/public/software/apps/ncl_ncarg/ncl630/bin/ncl}" -V
for command in ncdump ncks rsync ssh; do
  command -v "$command"
done
