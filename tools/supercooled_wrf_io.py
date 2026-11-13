"""Validated tiled WRF extraction for resolved supercooled liquid water paths."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from netCDF4 import Dataset
from render_yunnan_airport_aviation_preview import BJT, wrf_times
from supercooled_water_path import G, integrate_paths, thermodynamics

LEVELS = [1, 5, 10, 25, 50, 100, 200, 400, 800, 1600]
DIM3 = ("Time", "bottom_top", "south_north", "west_east")
DIMW = ("Time", "bottom_top_stag", "south_north", "west_east")
UNITS = {
    "T": {"K"},
    "P": {"Pa"},
    "PB": {"Pa"},
    "QVAPOR": {"kg kg-1", "kg/kg"},
    "QCLOUD": {"kg kg-1", "kg/kg"},
    "QRAIN": {"kg kg-1", "kg/kg"},
    "PH": {"m2 s-2", "m2/s2"},
    "PHB": {"m2 s-2", "m2/s2"},
}


def atomic_json(path: Path, value: dict) -> None:
    temporary = path.with_suffix(".tmp")
    temporary.write_text(
        json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False),
        encoding="utf-8",
    )
    temporary.replace(path)


def stats(field: np.ndarray) -> dict:
    valid = field[np.isfinite(field)]
    positive = valid[valid > 0]
    return {
        "valid_columns": int(valid.size),
        "missing_columns": int(field.size - valid.size),
        "positive_columns": int(positive.size),
        "max_g_m2": float(valid.max()) if valid.size else None,
        "mean_g_m2": float(valid.mean()) if valid.size else None,
        "positive_p50_p90_p99_g_m2": np.percentile(positive, [50, 90, 99]).tolist()
        if positive.size
        else [],
        "above_colorbar_columns": int(np.sum(valid > LEVELS[-1])),
    }


def extract(source: Path, index: int) -> tuple:
    initial = source.stat()
    digest = hashlib.sha256()
    with Dataset(source) as ds:
        times = wrf_times(ds)
        if not 0 <= index < len(times):
            raise ValueError(f"time index {index} outside {len(times)} saved times")
        elapsed = (times[index] - times[0]).total_seconds() / 3600
        if elapsed < 12:
            raise ValueError("Select a time after the 12-hour spin-up")
        metadata = {}
        for name, units in UNITS.items():
            if name not in ds.variables:
                raise ValueError(f"Required variable missing: {name}")
            v = ds[name]
            expected = DIMW if name in ("PH", "PHB") else DIM3
            if v.dimensions != expected or getattr(v, "units", "").strip() not in units:
                raise ValueError(
                    f"Unsupported {name} dimensions/units: "
                    f"{v.dimensions}, {getattr(v, 'units', '')}"
                )
            metadata[name] = {
                "dimensions": list(v.dimensions),
                "units": v.units,
                "description": getattr(v, "description", ""),
            }
        description = str(getattr(ds["T"], "description", "")).lower()
        if "potential temperature" not in description or "moist" in description:
            raise ValueError(
                f"T must be dry perturbation potential temperature, got {description}"
            )
        ny, nx = len(ds.dimensions["south_north"]), len(ds.dimensions["west_east"])
        nz = len(ds.dimensions["bottom_top"])
        if len(ds.dimensions["bottom_top_stag"]) != nz + 1:
            raise ValueError("Interface level count must equal mass levels + 1")
        if (
            ds["XLAT"].dimensions != ("Time", "south_north", "west_east")
            or ds["XLONG"].dimensions != ds["XLAT"].dimensions
        ):
            raise ValueError("Unexpected coordinate dimensions")
        lat, lon = (
            np.ma.asarray(ds[n][index], dtype=float).filled(np.nan)
            for n in ("XLAT", "XLONG")
        )
        if not np.isfinite(lat).all() or not np.isfinite(lon).all():
            raise ValueError("Invalid horizontal coordinates")
        result, totals, ranges = {}, {}, {}
        for start in range(0, ny, 32):
            stop = min(start + 32, ny)
            fields = {}
            for name in UNITS:
                value = np.ma.asarray(
                    ds[name][index, :, start:stop, :], dtype=float
                ).filled(np.nan)
                fields[name] = value
                digest.update(name.encode())
                digest.update(value.astype("<f8").tobytes())
                finite = value[np.isfinite(value)]
                if finite.size:
                    old = ranges.get(name, [float("inf"), -float("inf")])
                    ranges[name] = [
                        min(old[0], float(finite.min())),
                        max(old[1], float(finite.max())),
                    ]
            temperature, density = thermodynamics(
                fields["T"] + 300, fields["P"] + fields["PB"], fields["QVAPOR"]
            )
            thickness = np.diff((fields["PH"] + fields["PHB"]) / G, axis=0)
            paths, counts = integrate_paths(
                temperature, density, thickness, fields["QCLOUD"], fields["QRAIN"]
            )
            for key, value in paths.items():
                if key not in result:
                    result[key] = np.full((ny, nx), np.nan)
                result[key][start:stop] = value
            for key, value in counts.items():
                totals[key] = totals.get(key, 0) + value
        for value in (lat, lon):
            digest.update(value.astype("<f8").tobytes())
        digest.update(times[index].isoformat().encode())
        info = {
            "input": str(source.resolve()),
            "size": initial.st_size,
            "mtime_ns": initial.st_mtime_ns,
            "selected_decoded_fields_sha256": digest.hexdigest(),
            "hash_scope": (
                "selected time only, ordered 32-row decoded float64 tiles "
                "plus lat/lon/time; not full wrfout"
            ),
            "init_utc": times[0].isoformat(),
            "valid_utc": times[index].isoformat(),
            "valid_bjt": times[index].astimezone(BJT).strftime("%Y-%m-%d %H:%M BJT"),
            "lead_hours": elapsed,
            "time_index": index,
            "saved_times": len(times),
            "shape_zyx": [nz, ny, nx],
            "variables": metadata,
            "input_ranges": ranges,
            "microphysics": int(getattr(ds, "MP_PHYSICS", -1)),
            "qc": totals,
        }
    final = source.stat()
    if (final.st_size, final.st_mtime_ns) != (initial.st_size, initial.st_mtime_ns):
        raise RuntimeError("Input changed during extraction; refusing preview")
    np.testing.assert_allclose(
        result["total"], result["cloud"] + result["rain"], equal_nan=True
    )
    info["statistics"] = {key: stats(value) for key, value in result.items()}
    return lon, lat, result, info


def save_fields(
    path: Path, lon: np.ndarray, lat: np.ndarray, fields: dict, info: dict
) -> None:
    temporary = path.with_suffix(".tmp.nc")
    with Dataset(temporary, "w") as ds:
        ds.createDimension("y", lat.shape[0])
        ds.createDimension("x", lat.shape[1])
        ds.setncattr(
            "method", "sum(rho_d*q*dz) where mid-layer T<273.15 K; resolved liquid only"
        )
        ds.setncattr("valid_time", info["valid_utc"])
        ds.setncattr("input", info["input"])
        for name, value in {"latitude": lat, "longitude": lon, **fields}.items():
            v = ds.createVariable(name, "f4", ("y", "x"), zlib=True, fill_value=-9999.0)
            v.units = (
                "degree_north"
                if name == "latitude"
                else "degree_east"
                if name == "longitude"
                else "g m-2"
            )
            v[:] = np.ma.masked_invalid(value)
    temporary.replace(path)
