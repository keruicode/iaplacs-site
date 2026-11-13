"""Standard-library-only guard, called before scientific imports by plot CLIs."""

import os
import subprocess
from pathlib import Path


def require_plot_allocation() -> None:
    """Reject direct plotting without a verified compute-node allocation."""
    guard = Path(__file__).with_name("require_plot_compute.sh")
    result = subprocess.run(["bash", str(guard)], check=False)
    if result.returncode:
        raise SystemExit(
            "Plotting requires a compute job. Use bash submit_plot_job.sh SCRIPT ARGS."
        )
    for name in (
        "OMP_NUM_THREADS",
        "OPENBLAS_NUM_THREADS",
        "MKL_NUM_THREADS",
        "BLIS_NUM_THREADS",
        "NUMEXPR_NUM_THREADS",
        "VECLIB_MAXIMUM_THREADS",
        "MAGICK_THREAD_LIMIT",
    ):
        os.environ[name] = "1"
