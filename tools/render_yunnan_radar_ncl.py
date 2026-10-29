"""Isolated NCL radar preview from checked mass fields, not native DBZ."""

from __future__ import annotations

import argparse
import hashlib
import logging
import os
import subprocess
import tempfile
from datetime import UTC, datetime
from pathlib import Path

import numpy as np
from netCDF4 import Dataset
from render_work_visibility import atomic_json, is_current, select_indices
from render_yunnan_airport_aviation_preview import (
    BJT,
    REGION_PROFILES,
    configure_matplotlib,
    display_region,
    shp_lines,
    wrf_times,
)
from render_yunnan_radar import build_parser as radar_parser
from render_yunnan_radar import save_maps
from render_yunnan_radar import source_signature as base_signature

INPUTS = ("P", "PB", "T", "QVAPOR", "QRAIN", "QSNOW", "QGRAUP")
LOG = logging.getLogger(__name__)


def checked_inputs(ds: Dataset, index: int) -> tuple[dict, dict]:
    """Return finite 3-D Pa/K-perturbation/kg-kg inputs and negative-Q counts."""
    fields, negatives = {}, {}
    for name in INPUTS:
        field = np.ma.asarray(ds[name][index], dtype=np.float64)
        if field.ndim != 3 or np.ma.getmaskarray(field).any():
            raise ValueError(f"Invalid dimensions/missing {name} at {index}")
        values = np.asarray(field)
        if not np.isfinite(values).all():
            raise ValueError(f"Nonfinite {name} at {index}")
        fields[name] = values
        if name.startswith("Q"):
            negatives[name] = int((values < 0).sum())
    if len({v.shape for v in fields.values()}) != 1:
        raise ValueError("Radar input grids differ")
    if np.any(fields["P"] + fields["PB"] <= 0):
        raise ValueError("Nonpositive full pressure")
    if np.any(fields["T"] + 300 <= 0):
        raise ValueError("Nonpositive potential temperature")
    return fields, negatives


def diagnose(fields: dict, executable: Path, script: Path, root: Path) -> np.ndarray:
    """Run the reference NCL diagnostic on a disposable checked input copy."""
    with tempfile.TemporaryDirectory(prefix="ncl_radar_", dir=root) as directory:
        source, target = Path(directory) / "input.nc", Path(directory) / "dbz.nc"
        with Dataset(source, "w") as ds:
            dims = ("bottom_top", "south_north", "west_east")
            for name, size in zip(dims, fields["P"].shape, strict=True):
                ds.createDimension(name, size)
            for name, values in fields.items():
                ds.createVariable(name, "f8", dims)[:] = values
        env = dict(os.environ)
        env["NCARG_ROOT"] = str(executable.resolve().parent.parent)
        result = subprocess.run(
            [
                str(executable),
                "-Q",
                f'source="{source}"',
                f'target="{target}"',
                str(script),
            ],
            check=True,
            capture_output=True,
            text=True,
            env=env,
            timeout=600,
        )
        if "fatal:" in (result.stdout + result.stderr).lower() or not target.exists():
            raise RuntimeError(f"NCL failed: {result.stdout}\n{result.stderr}")
        with Dataset(target) as ds:
            output = np.ma.asarray(ds["DBZ_MAX"][:])
            if np.ma.getmaskarray(output).any() or not np.isfinite(output).all():
                raise ValueError("Missing/nonfinite NCL composite")
            output = np.asarray(output).copy()
        if output.shape != fields["P"].shape[1:] or output.max() > 100:
            raise ValueError("NCL composite grid/range failed; do not mask into holes")
        return output


def build_parser() -> argparse.ArgumentParser:
    parser = radar_parser()
    parser.description = __doc__
    parser.add_argument("--ncl", required=True, type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO)
    args = build_parser().parse_args(argv)
    if args.dpi < 400:
        raise ValueError("PNG requires at least 400 dpi")
    args.output.mkdir(parents=True, exist_ok=True)
    source = args.input.resolve()
    script = Path(__file__).with_name("diagnose_radar_composite.ncl")
    before = source.stat()
    signature = base_signature(source, args)
    signature["method"] = "ncl_wrf_dbz_fixed_intercept_v1"
    signature["diagnostic_hashes"] = {
        p.name: hashlib.sha256(p.read_bytes()).hexdigest()
        for p in (Path(__file__), script)
    }
    if args.if_needed and is_current(args.output, signature):
        LOG.info("NCL radar images are current: %s", args.output)
        return 0
    digest = hashlib.sha256()
    fields, audits = [], []
    with Dataset(source) as ds:
        times = wrf_times(ds)
        indices = select_indices(times, args.start, args.count)
        lat, lon = np.asarray(ds["XLAT"][0]), np.asarray(ds["XLONG"][0])
        if (
            lat.shape != lon.shape
            or not np.isfinite(lat).all()
            or not np.isfinite(lon).all()
        ):
            raise ValueError("Invalid coordinates")
        extent = display_region(
            lat, lon, args.domain, REGION_PROFILES["yunnan"]["default_region"]
        )
        digest.update(lat.tobytes())
        digest.update(lon.tobytes())
        for index in indices:
            inputs, negatives = checked_inputs(ds, index)
            for values in inputs.values():
                digest.update(values.tobytes())
            composite = diagnose(inputs, args.ncl, script, args.output)
            if composite.shape != lat.shape:
                raise ValueError("Coordinates differ from mass field grid")
            fields.append(np.ma.asarray(composite))
            audit = {
                "source_index": index,
                "valid_time": times[index].astimezone(BJT).isoformat(),
                "minimum_dbz": float(composite.min()),
                "maximum_dbz": float(composite.max()),
                "above_70_columns": int((composite >= 70).sum()),
                "negative_q_clipped_by_ncl": negatives,
            }
            audits.append(audit)
            LOG.info("NCL diagnostic: %s", audit)
    after = source.stat()
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise RuntimeError("Source changed during diagnostic")
    configure_matplotlib()
    frame = save_maps(
        args.output,
        lon,
        lat,
        fields,
        [times[i].astimezone(BJT) for i in indices],
        extent,
        shp_lines(args.province_shp),
        shp_lines(args.city_shp),
        times[0].astimezone(BJT).strftime("%Y-%m-%d %H:%M BJT"),
        args.dpi,
    )
    atomic_json(
        args.output / "production_manifest.json",
        {
            "run_time": times[0].isoformat(),
            "generated_at": datetime.now(UTC).isoformat(),
            "source_signature": signature,
            "source_domain": args.domain,
            "extent": list(extent),
            "selected_input_sha256": digest.hexdigest(),
            "code_sha256": {
                p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                for p in (
                    Path(__file__),
                    script,
                    Path(__file__).with_name("render_yunnan_radar.py"),
                )
            },
            "method": "NCL wrf_dbz ivarint=0 iliqskin=0; vertical maximum; rain/snow/graupel",
            "qc": {"raw_data_modified": False, "hours": audits},
            "products": [
                {
                    "id": "airport_radar",
                    "title": "模拟雷达回波",
                    "unit": "组合反射率（dBZ）",
                    "description": "",
                    "frames": [frame],
                }
            ],
        },
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
