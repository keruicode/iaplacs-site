"""Select a completed run's visibility input without deriving any data."""

from pathlib import Path

from cloud_visibility_moments import cloud_groups
from netCDF4 import Dataset


def select_source(
    d01: Path, profile: str, *, prefer_nested: bool = True
) -> tuple[Path, str] | None:
    """Prefer d02; within that domain prefer VIS_MIN, then VIS, then cloud moments."""
    candidates = (
        (d01,)
        if profile == "ningxia" or not prefer_nested
        else (d01.with_name(d01.name.replace("d01", "d02", 1)), d01)
    )
    for path in candidates:
        if not path.is_file():
            continue
        with Dataset(path) as ds:
            if len(ds.dimensions["Time"]) < 14:
                continue
            names = ("VIS_MIN",) if profile == "ningxia" else ("VIS_MIN", "VIS")
            if any(n in ds.variables for n in names):
                return path, "native"
            if profile == "ningxia":
                continue
            if not {"P", "PB", "T", "QVAPOR"}.issubset(ds.variables):
                continue
            try:
                cloud_groups(ds.variables)
            except ValueError:
                continue
            return path, "diagnostic"
    return None
