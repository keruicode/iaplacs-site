#!/usr/bin/env python3
"""Export compact, losslessly compressed website fields on the Ningxia grid."""

from __future__ import annotations

import argparse
import hashlib
import json
import logging
from datetime import UTC, datetime, timedelta
from itertools import pairwise
from pathlib import Path

LOG = logging.getLogger(__name__)
REGION = (104.0, 107.8, 35.0, 39.7)
VERSION = 2


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def export(source: Path, output: Path) -> Path:
    """Read one stable run; write float32 products with missing values preserved."""
    import numpy as np
    from netCDF4 import Dataset, chartostring, stringtochar
    from render_work_visibility import quality_control, visibility_variable
    from render_yunnan_radar import composite_reflectivity
    from supercooled_water_path import G, integrate_paths, thermodynamics
    from supercooled_wrf_io import UNITS

    source = source.resolve()
    before = source.stat()
    signature = {
        "name": source.name,
        "size": before.st_size,
        "mtime_ns": before.st_mtime_ns,
        "version": VERSION,
        "code_sha256": sha256(Path(__file__)),
        "helpers": {
            name: sha256(Path(__file__).with_name(name))
            for name in (
                "render_work_visibility.py",
                "render_yunnan_radar.py",
                "supercooled_water_path.py",
            )
        },
    }
    output.mkdir(parents=True, exist_ok=True)
    manifest = output / "index.json"
    if manifest.exists():
        old = json.loads(manifest.read_text(encoding="utf-8"))
        previous = output / old["file"]
        if (
            old.get("signature") == signature
            and previous.is_file()
            and sha256(previous) == old["sha256"]
        ):
            return manifest
    temporary = output / ".ningxia.partial.nc"
    try:
        with Dataset(source) as ds, Dataset(temporary, "w", format="NETCDF4") as nc:
            times = [
                datetime.strptime(str(t), "%Y-%m-%d_%H:%M:%S").replace(tzinfo=UTC)
                for t in chartostring(ds["Times"][:])
            ]
            if len(times) < 14 or any(
                b - a != timedelta(hours=1) for a, b in pairwise(times)
            ):
                raise ValueError(
                    "A regular hourly run with post-spin-up data is required"
                )
            indices = list(range(13, min(len(times), 49)))
            lat = np.ma.asarray(ds["XLAT"][0], dtype=float).filled(np.nan)
            lon = np.ma.asarray(ds["XLONG"][0], dtype=float).filled(np.nan)
            inside = (
                (lon >= REGION[0])
                & (lon <= REGION[1])
                & (lat >= REGION[2])
                & (lat <= REGION[3])
            )
            yy, xx = np.where(inside)
            if not yy.size:
                raise ValueError("WRF grid does not intersect the Ningxia region")
            ys, xs = slice(yy.min(), yy.max() + 1), slice(xx.min(), xx.max() + 1)
            spatial_mask = ~inside[ys, xs]
            shape = spatial_mask.shape
            nc.createDimension("Time", len(indices))
            nc.createDimension("south_north", shape[0])
            nc.createDimension("west_east", shape[1])
            nc.createDimension("DateStrLen", 19)
            nc.time_zone = "UTC; add 8 hours for Beijing time"
            nc.START_DATE = times[0].strftime("%Y-%m-%d_%H:%M:%S")
            nc.description = "WRF-style derived products, not a WRF restart file"
            nc.title = "Ningxia regional forecast numerical products"
            nc.source_file = source.name
            nc.source_domain = f"d{int(getattr(ds, 'GRID_ID', 1)):02d}"
            nc.spatial_selection = "Native grid cropped to 104-107.8E, 35-39.7N"
            nc.forecast_reference_time = times[0].isoformat()
            nc.history = (
                "Derived website products; float32, zlib shuffle; no quantization"
            )
            nc.input_signature = json.dumps(signature, sort_keys=True)
            for key in ("DX", "DY", "MAP_PROJ", "TRUELAT1", "TRUELAT2", "STAND_LON"):
                if key in ds.ncattrs():
                    nc.setncattr(key, ds.getncattr(key))
            for name, data, units in (
                ("XLAT", lat[ys, xs], "degrees_north"),
                ("XLONG", lon[ys, xs], "degrees_east"),
            ):
                v = nc.createVariable(
                    name,
                    "f4",
                    ("Time", "south_north", "west_east"),
                    zlib=True,
                    complevel=4,
                )
                v[:] = data
                v.units = units
                v.standard_name = "latitude" if name == "XLAT" else "longitude"
            epoch = times[0]
            time_units = f"minutes since {epoch:%Y-%m-%d %H:%M:%S} +00:00"

            def add_time(dim: str, entries: list[int], hours: int) -> None:
                suffix = "" if dim == "Time" else dim.removeprefix("Time")
                v = nc.createVariable(f"XTIME{suffix}", "f8", (dim,))
                v.units, v.calendar, v.standard_name = time_units, "standard", "time"
                v[:] = [(times[i] - epoch).total_seconds() / 60 for i in entries]
                for label, offset in (
                    (f"Times{suffix}", 0),
                    (f"Times{suffix}_START", hours),
                ):
                    text = nc.createVariable(label, "S1", (dim, "DateStrLen"))
                    text[:] = stringtochar(
                        np.array(
                            [
                                (times[i] - timedelta(hours=offset)).strftime(
                                    "%Y-%m-%d_%H:%M:%S"
                                )
                                for i in entries
                            ],
                            dtype="S19",
                        )
                    )
                    text.description = (
                        "UTC interval start"
                        if offset
                        else "UTC valid time / interval end"
                    )

            add_time("Time", indices, 1)
            fields = {}

            def variable(name: str, units: str, description: str, dim: str = "Time"):
                v = nc.createVariable(
                    name,
                    "f4",
                    (dim, "south_north", "west_east"),
                    zlib=True,
                    complevel=4,
                    shuffle=True,
                    fill_value=np.float32(9.96921e36),
                    chunksizes=(1, min(shape[0], 128), min(shape[1], 128)),
                )
                v.units, v.long_name = units, description
                v.description = description
                if dim == "Time":
                    v.coordinates = "XTIME XLAT XLONG"
                fields[name] = {"units": units, "description": description}
                return v

            def read(name: str, i: int, vertical: bool = False):
                v = ds[name]
                expected = ("Time", "bottom_top", "south_north", "west_east")
                if name in ("PH", "PHB"):
                    expected = ("Time", "bottom_top_stag", "south_north", "west_east")
                if not vertical:
                    expected = ("Time", "south_north", "west_east")
                if v.dimensions != expected:
                    raise ValueError(
                        f"Unexpected dimensions for {name}: {v.dimensions}"
                    )
                key = (i, slice(None), ys, xs) if vertical else (i, ys, xs)
                return np.ma.asarray(v[key], dtype=float).filled(np.nan)

            def store(v, row: int, data) -> None:
                values = np.ma.asarray(data, dtype=float)
                v[row] = np.ma.masked_where(
                    spatial_mask | ~np.isfinite(values.filled(np.nan)), values
                )

            rain_names = [
                n
                for n in ("RAINC", "RAINNC", "GRAUPELNC", "HAILNC")
                if n in ds.variables
            ]
            if not {"RAINC", "RAINNC"}.issubset(rain_names):
                raise ValueError("RAINC and RAINNC are required")
            frozen_names = [
                n for n in ("SNOWNC", "GRAUPELNC", "HAILNC") if n in ds.variables
            ]
            for name in set(rain_names + frozen_names):
                if str(getattr(ds[name], "units", "")).strip() != "mm":
                    raise ValueError(f"{name} units must be mm")

            def accumulation(names: list[str], a: int, b: int):
                delta = sum(read(n, b) - read(n, a) for n in names)
                # Website clips negative accumulation differences to zero.
                return np.maximum(delta, 0)

            rain = variable("RAIN_1H", "mm", "Hourly precipitation; website formula")
            rain.source_variables = "+".join(rain_names)
            rain.interval_start = "Times_START"
            rain.interval_end = "Times"
            frozen = None
            if frozen_names:
                frozen = variable(
                    "SOLID_1H",
                    "mm",
                    "Hourly snow + graupel + hail water equivalent",
                )
                frozen.source_variables = "+".join(frozen_names)
                frozen.interval_start = "Times_START"
                frozen.interval_end = "Times"
            vis_source = visibility_variable(ds, "auto")
            vis = None
            if vis_source is not None:
                vis = variable(vis_source.name, "m", "Lowest model layer visibility")
                vis.source_variable = vis_source.name
                vis.time_kind = (
                    "hourly_minimum"
                    if vis_source.name == "VIS_MIN"
                    else "instantaneous"
                )
                vis.quality_control = (
                    "Website QC: invalid/nonpositive/>100km/model boundary masked"
                )
            radar = None
            if "DBZ" in ds.variables:
                if ds["DBZ"].dimensions != (
                    "Time",
                    "bottom_top",
                    "south_north",
                    "west_east",
                ):
                    raise ValueError("Unsupported DBZ dimensions")
                if getattr(ds["DBZ"], "units", "").strip().lower() not in ("", "dbz"):
                    raise ValueError("Unsupported DBZ units")
                radar = variable(
                    "MDBZ",
                    "dBZ",
                    "Maximum valid native DBZ over model levels",
                )
                radar.quality_control = "Same as Ningxia website composite_reflectivity"
            water = {}
            if set(UNITS).issubset(ds.variables):
                for name, units in UNITS.items():
                    if getattr(ds[name], "units", "").strip() not in units:
                        raise ValueError(f"Unsupported water-path units: {name}")
                description = str(getattr(ds["T"], "description", "")).lower()
                if "potential temperature" not in description or "moist" in description:
                    raise ValueError("T must be dry perturbation potential temperature")
                for kind in ("cloud", "rain"):
                    water[kind] = variable(
                        f"SLWP_{kind.upper()}",
                        "g m-2",
                        f"Vertically integrated {kind} liquid water at T < 273.15 K",
                    )
            for row, i in enumerate(indices):
                store(rain, row, accumulation(rain_names, i - 1, i))
                if frozen is not None:
                    store(frozen, row, accumulation(frozen_names, i - 1, i))
                if vis is not None:
                    # QC before crop keeps only true model boundaries masked.
                    field, _ = quality_control(vis_source[i, 0])
                    store(vis, row, field[ys, xs])
                if radar is not None:
                    field, _ = composite_reflectivity(ds["DBZ"][i])
                    store(radar, row, field[ys, xs])
                if water:
                    f = {n: read(n, i, vertical=True) for n in UNITS}
                    t, rho = thermodynamics(f["T"] + 300, f["P"] + f["PB"], f["QVAPOR"])
                    dz = np.diff((f["PH"] + f["PHB"]) / G, axis=0)
                    paths, _ = integrate_paths(t, rho, dz, f["QCLOUD"], f["QRAIN"])
                    for kind, v in water.items():
                        store(v, row, paths[kind])
            for hours in (12, 24):
                ends = [
                    i
                    for i in indices
                    if i - hours >= 12 and (times[i].hour + 8) % 24 in (8, 20)
                ]
                if not ends:
                    continue
                dim = f"Time_{hours}H"
                nc.createDimension(dim, len(ends))
                add_time(dim, ends, hours)
                v = variable(
                    f"RAIN_{hours}H",
                    "mm",
                    f"{hours}-hour precipitation after spin-up",
                    dim,
                )
                v.source_variables = "+".join(rain_names)
                v.interval_start = f"Times_{hours}H_START"
                v.interval_end = f"Times_{hours}H"
                v.cell_methods = f"{dim}: sum"
                for row, i in enumerate(ends):
                    store(v, row, accumulation(rain_names, i - hours, i))
            domain = nc.source_domain
            init = nc.forecast_reference_time
        after = source.stat()
        if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
            raise RuntimeError("Source changed; refusing publication")
        with Dataset(temporary) as check:
            for name in fields:
                if not np.ma.asarray(check[name][:]).count():
                    raise ValueError(f"No valid cells in exported variable {name}")
        digest = sha256(temporary)
        name = f"ningxia_{times[0]:%Y%m%d%H}_{domain}_{digest[:16]}.nc"
        destination = output / name
        temporary.replace(destination)
        metadata = {
            "schema_version": 1,
            "file": name,
            "sha256": digest,
            "bytes": destination.stat().st_size,
            "signature": signature,
            "run_id": times[0].strftime("%Y%m%d_%H"),
            "init_utc": init,
            "domain": domain,
            "region": list(REGION),
            "fields": fields,
            "valid_times_utc": [times[i].isoformat() for i in indices],
        }
        pending = output / ".index.partial.json"
        pending.write_text(
            json.dumps(metadata, indent=2, allow_nan=False), encoding="utf-8"
        )
        pending.replace(manifest)
        LOG.info("Exported %s (%s bytes)", destination, destination.stat().st_size)
        return manifest
    finally:
        temporary.unlink(missing_ok=True)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    from plot_runtime import require_plot_allocation

    require_plot_allocation()
    logging.basicConfig(level=logging.INFO)
    export(args.input, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
