#!/usr/bin/env python3
"""Instantaneous cloud-visibility fallback; never label it as native VIS_MIN.

Three-moment extinction follows FOG/程序/三参数能见度.py (NCL vis1).
Dry-air density is reconstructed with the ideal gas law, not asserted to be
identical to the microphysics substep RHO_0. Aerosols/rain/ice are not included.
"""

from __future__ import annotations

import hashlib
import json
import logging
import tempfile
from pathlib import Path

import numpy as np
from cloud_visibility_moments import (
    METHOD,
    cloud_groups,
    extinction,
    visibility_from_extinction,
)
from netCDF4 import Dataset
from render_work_visibility import (
    atomic_json,
    build_parser,
    is_current,
    render,
    select_indices,
    source_signature,
    visibility_variable,
)
from render_yunnan_airport_aviation_preview import wrf_times

LOG = logging.getLogger(__name__)
DIMS = ("Time", "bottom_top", "south_north", "west_east")
DERIVED = "DIAGNOSTIC_CLOUD_VIS"


def dry_air_density(p: np.ndarray, theta: np.ndarray, qv: np.ndarray) -> np.ndarray:
    """Return kg dry air/m3 from pressure Pa, dry theta K, and kg water/kg dry air.

    Temperature follows WRF/NCL wrf_tk, Rd=287 J/kg/K, Cp=1004.5 J/kg/K.
    p = rho_d * Rd * Tk * (1 + Rv/Rd * qv), Rv=461.6 J/kg/K.
    Invalid meteorology must be masked by the caller, never clipped here.
    """
    if not (p.shape == theta.shape == qv.shape):
        raise ValueError("Density inputs must have equal shapes")
    if not all(np.isfinite(a).all() for a in (p, theta, qv)):
        raise ValueError("Nonfinite density input")
    if np.any(p <= 0) or np.any(theta <= 0) or np.any(qv < 0):
        raise ValueError("Nonphysical density input")
    tk = theta * (p / 100000.0) ** (287.0 / 1004.5)
    return p / (287.0 * tk * (1.0 + (461.6 / 287.0) * qv))


def diagnose(fields: dict[str, np.ndarray], groups: list[tuple]) -> tuple:
    """Diagnose lowest-level instantaneous cloud visibility; missing stays masked."""
    values = {
        n: np.ma.asarray(a, dtype=float).filled(np.nan) for n, a in fields.items()
    }
    if len({a.shape for a in values.values()}) != 1:
        raise ValueError("Diagnostic input grid mismatch")
    p = values["P"] + values["PB"]
    theta = values["T"] + 300.0
    qv = values["QVAPOR"]
    good = np.logical_and.reduce([np.isfinite(a) for a in values.values()])
    good &= (p > 0) & (theta > 0) & (qv >= -1e-12)
    tiny = int(((qv < 0) & (qv >= -1e-12)).sum())
    qv = np.maximum(qv, 0)
    for q, n, z in groups:
        tiny += int(((values[q] < 0) & (values[q] >= -1e-12)).sum())
        good &= (values[q] >= -1e-12) & (values[n] >= 0) & (values[z] >= 0)
        # Cloud mass with missing number or sixth moment is not clear weather.
        good &= (values[q] < 1e-10) | ((values[n] > 0) & (values[z] > 0))
    if not good.any():
        raise ValueError("No valid cloud diagnostic inputs")
    rho = dry_air_density(p[good], theta[good], qv[good])
    total = np.zeros(rho.shape)
    for q, n, z in groups:
        total += extinction(values[q][good], values[n][good], values[z][good], rho)
    result = np.ma.masked_all(p.shape, dtype=np.float64)
    result[good] = visibility_from_extinction(total)
    return result, {
        "invalid_input_cells": int((~good).sum()),
        "tiny_negative_mixing_ratios_treated_as_zero": tiny,
        "zero_cloud_extinction_cells": int((total == 0).sum()),
        "density_min_kg_m3": float(rho.min()),
        "density_max_kg_m3": float(rho.max()),
        "below_1000m_cells": int((result.compressed() < 1000).sum()),
    }


def extract(source: Path, output: Path, start: int, count: int) -> dict:
    """Read only selected lowest layers, preserving initialization and actual Times."""
    before = source.stat()
    digest = hashlib.sha256()
    with Dataset(source) as ds:
        groups = cloud_groups(ds.variables)
        names = ["P", "PB", "T", "QVAPOR"] + [n for group in groups for n in group]
        for name in names:
            if ds[name].dimensions != DIMS:
                raise ValueError(f"Unsupported dimensions: {name}")
        expected = {"P": "Pa", "PB": "Pa", "T": "K", "QVAPOR": "kg kg-1"}
        expected.update({q: "kg kg-1" for q, _, _ in groups})
        for name, units in expected.items():
            if ds[name].units.strip() != units:
                raise ValueError(f"Unexpected units for {name}: {ds[name].units}")
        times = wrf_times(ds)
        indices = select_indices(times, start, count)
        audit = []
        with Dataset(output, "w") as out:
            for dim in ("Time", "DateStrLen", "south_north", "west_east"):
                out.createDimension(dim, len(ds.dimensions[dim]))
            out.createDimension("bottom_top", 1)
            out.createVariable("Times", "S1", ("Time", "DateStrLen"))[:] = ds["Times"][
                :
            ]
            for name in ("XLAT", "XLONG"):
                a = np.asarray(ds[name][0], dtype=float)
                digest.update(a.tobytes())
                out.createVariable(name, "f8", ("Time", "south_north", "west_east"))[
                    0
                ] = a
            v = out.createVariable(DERIVED, "f4", DIMS, zlib=True, fill_value=-9999)
            v.units = "m"
            v.description = "Instantaneous cloud-only three-moment visibility estimate"
            for i in indices:
                fields = {n: ds[n][i, 0, :, :] for n in names}
                for n, a in fields.items():
                    digest.update(n.encode())
                    digest.update(
                        np.ma.asarray(a, dtype=float).filled(np.nan).tobytes()
                    )
                result, stats = diagnose(fields, groups)
                v[i, 0] = result
                audit.append(
                    {"source_index": i, "valid_time": times[i].isoformat(), **stats}
                )
                LOG.info("Diagnosed %s: %s", times[i], stats)
    after = source.stat()
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        output.unlink()
        raise RuntimeError("WRF changed during extraction; use a completed run")
    return {
        "original_wrf": str(source.resolve()),
        "source_size": before.st_size,
        "source_mtime_ns": before.st_mtime_ns,
        "selected_input_sha256": digest.hexdigest(),
        "method": METHOD,
        "density": "reconstructed dry-air density from P+PB, T+300, QVAPOR",
        "number_concentration": "linear per kg dry air; legacy NW log10 attribute ignored explicitly",
        "cloud_groups": groups,
        "hourly_minimum": False,
        "includes_rain_ice_aerosol_extinction": False,
        "hours": audit,
    }


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    parser.description = __doc__
    parser.add_argument("--production", action="store_true")
    args = parser.parse_args(argv)
    if args.profile not in {"xinjiang", "yunnan"} or args.dpi < 400:
        raise ValueError("Cloud fallback supports Xinjiang/Yunnan, at least 400 dpi")
    for path in (args.input, args.province_shp, args.county_shp):
        if path is not None and not path.is_file():
            raise FileNotFoundError(path)
    logging.basicConfig(level=logging.INFO)
    original = args.input
    # Native fields arriving later must invalidate any earlier diagnostic result.
    with Dataset(original) as ds:
        native = visibility_variable(ds, "auto")
        if native is not None:
            args.variable = "auto"
            return render(args)
    signature = source_signature(original, args)
    code_hashes = {
        name: hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest()
        for name in (
            Path(__file__).name,
            "cloud_visibility_moments.py",
            "render_work_visibility.py",
        )
    }
    signature.update(diagnostic_code_hashes=code_hashes, production=args.production)
    if args.if_needed and is_current(args.output, signature):
        LOG.info("Diagnostic visibility already current: %s", args.output)
        return 0
    args.output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix=".visibility-", dir=args.output.parent
    ) as temp:
        extracted = Path(temp) / "diagnostic_fields.nc"
        provenance = extract(original, extracted, args.start, args.count)
        provenance["code_hashes"] = code_hashes
        args.input = extracted
        args.variable = DERIVED
        args.if_needed = False
        status = render(args)
        if status:
            return status
    atomic_json(args.output / "diagnostic_provenance.json", provenance)
    path = args.output / "production_manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    manifest["source_signature"] = signature
    manifest["diagnostic_provenance"] = provenance
    manifest["preview_only"] = not args.production
    manifest["products"][0]["unit"] = "最低模式层诊断能见度（米）"
    atomic_json(path, manifest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
