#!/usr/bin/env python3
"""Render WRF DBZ column maxima; no radar observations or model mutation."""

from __future__ import annotations

import argparse
import hashlib
import logging
import math
from datetime import UTC, datetime
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.axes import Axes
from matplotlib.collections import QuadMesh
from matplotlib.colors import BoundaryNorm, ListedColormap
from matplotlib.figure import Figure
from netCDF4 import Dataset
from render_work_visibility import atomic_json, is_current, select_indices
from render_yunnan_airport_aviation_preview import (
    BJT,
    REGION_PROFILES,
    configure_matplotlib,
    crop_indices,
    decorate,
    display_region,
    shp_lines,
    wrf_times,
)

LOG = logging.getLogger(__name__)
LEVELS = np.arange(5, 75, 5)
RADAR_COLORS = [
    "#419df1",
    "#64e7eb",
    "#6dfa3d",
    "#00d800",
    "#019000",
    "#ffff00",
    "#e7c000",
    "#ff9000",
    "#ff0000",
    "#d60000",
    "#c00000",
    "#ff00f0",
    "#9600b4",
]
# NMC southwest composite palette, sampled from its published colorbar.
INVALID_COLOR = "#ffffff"
MAX_DBZ = 100.0  # Provisional numerical QC, not a radar warning threshold.
MIN_DBZ = -150.0  # Audited IAP microphysics no-echo floor.


def composite_reflectivity(raw: np.ndarray) -> tuple[np.ma.MaskedArray, dict]:
    """Reduce DBZ(z,y,x) in dBZ to column maxima, invalidating suspect columns."""
    values = np.ma.asarray(raw, dtype=np.float64)
    if values.ndim != 3 or values.shape[0] < 1 or min(values.shape[1:]) < 3:
        raise ValueError("DBZ must have nonempty (level, y, x) dimensions")
    data = values.filled(np.nan)
    missing = np.ma.getmaskarray(values) | ~np.isfinite(data)
    excessive = np.isfinite(data) & (data > MAX_DBZ)
    below_floor = np.isfinite(data) & (data < MIN_DBZ)
    suspect = (missing | excessive | below_floor).any(axis=0)
    boundary = np.zeros(suspect.shape, dtype=bool)
    boundary[[0, -1], :] = True
    boundary[:, [0, -1]] = True
    mask = suspect | boundary
    result = np.ma.array(np.max(np.where(missing, -np.inf, data), axis=0), mask=mask)
    if not result.count():
        raise ValueError("No valid DBZ columns; withholding radar product")
    finite = data[np.isfinite(data)]
    return result, {
        "total_columns": int(mask.size),
        "boundary_columns": int(boundary.sum()),
        "suspect_interior_columns": int((suspect & ~boundary).sum()),
        "over_100dbz_cells": int(excessive.sum()),
        "missing_cells": int(missing.sum()),
        "below_floor_cells": int(below_floor.sum()),
        "raw_max_dbz": float(finite.max()) if finite.size else None,
        "valid_composite_max_dbz": float(result.max()),
    }


def source_signature(source: Path, args: argparse.Namespace) -> dict:
    stat = source.stat()
    files = [
        Path(__file__),
        args.province_shp,
        args.city_shp,
        Path(__file__).with_name("render_yunnan_airport_aviation_preview.py"),
        Path(__file__).with_name("render_work_visibility.py"),
    ]
    return {
        "source": str(source.resolve()),
        "size": stat.st_size,
        "mtime_ns": stat.st_mtime_ns,
        "dependencies": {
            path.name: hashlib.sha256(path.read_bytes()).hexdigest()
            for path in files
            if path is not None
        },
        "start": args.start,
        "count": args.count,
        "domain": args.domain,
        "dpi": args.dpi,
        "qc": "dbz_column_qc_v1",
    }


def draw_panel(
    axis: Axes,
    lon: np.ndarray,
    lat: np.ndarray,
    field: np.ma.MaskedArray,
    extent: tuple,
    province: list,
    cities: list,
    compact: bool = False,
) -> QuadMesh:
    palette = ListedColormap(RADAR_COLORS)
    palette.set_under("white")
    palette.set_over("#ad90f0")
    palette.set_bad(INVALID_COLOR)
    # White is a display choice only; the QC mask remains in the manifest.
    axis.pcolormesh(
        lon,
        lat,
        np.ma.getmaskarray(field).astype(float),
        cmap=ListedColormap(["white", INVALID_COLOR]),
        vmin=0,
        vmax=1,
        shading="nearest",
        rasterized=True,
    )
    artist = axis.pcolormesh(
        lon,
        lat,
        field,
        cmap=palette,
        norm=BoundaryNorm(LEVELS, palette.N),
        shading="nearest",
        rasterized=True,
    )
    decorate(
        axis,
        province,
        cities,
        extent,
        REGION_PROFILES["yunnan"]["airports"],
        tick_size=18,
        plane_scale=0.12,
    )
    spacing = 4 if compact else 2
    ticks = np.arange(math.ceil(extent[0] / spacing) * spacing, extent[1], spacing)
    axis.set_xticks(ticks, [f"{value:g}°E" for value in ticks])
    for label in axis.get_xticklabels():
        label.set_horizontalalignment("center")
    if compact:
        axis.set_xticks(
            np.arange(math.ceil(extent[0] / 2) * 2, extent[1], 2), minor=True
        )
        axis.tick_params(which="minor", width=2, length=4, top=True)
    return artist


def colorbar(figure: Figure, artist: QuadMesh, axis: Axes) -> None:
    bar = figure.colorbar(artist, cax=axis, ticks=LEVELS, extend="both")
    bar.ax.tick_params(labelsize=18, width=3, length=8)
    bar.set_label("dBZ", fontsize=22)


def save_maps(
    output: Path,
    lon: np.ndarray,
    lat: np.ndarray,
    fields: list,
    times: list,
    extent: tuple,
    province: list,
    cities: list,
    initialization: str,
    dpi: int,
) -> dict:
    ratio = (extent[3] - extent[2]) / (extent[1] - extent[0])
    frames = []
    for field, moment in zip(fields, times, strict=True):
        name = f"radar_{moment:%Y%m%d%H%M}_BJT.png"
        fig = plt.figure(figsize=(12, max(5, 9.6 * ratio + 1.2)))
        grid = fig.add_gridspec(
            1,
            2,
            width_ratios=(30, 1),
            left=0.07,
            right=0.9,
            bottom=0.1,
            top=0.92,
            wspace=0.08,
        )
        axis = fig.add_subplot(grid[0, 0])
        artist = draw_panel(axis, lon, lat, field, extent, province, cities)
        axis.set_title(f"{moment:%m-%d %H:%M} BJT", fontsize=24, pad=10)
        colorbar(fig, artist, fig.add_subplot(grid[0, 1]))
        fig.savefig(output / name, dpi=dpi, bbox_inches="tight", pad_inches=0.05)
        plt.close(fig)
        frames.append(
            {
                "id": f"airport_radar_{moment:%Y%m%d%H%M}",
                "valid_time": moment.isoformat(),
                "time_kind": "instant",
                "lead_label": f"{moment:%m-%d %H:%M} BJT",
                "file": name,
            }
        )
    cols = min(4, len(fields))
    rows = math.ceil(len(fields) / cols)
    width = 4.7 * cols + 1.2
    panel_width = width * 0.84 / (cols + 0.28 * (cols - 1))
    height = max(4, panel_width * ratio * (rows + 0.18 * (rows - 1)) / 0.89)
    fig, axes = plt.subplots(
        rows,
        cols,
        squeeze=False,
        figsize=(width, height),
    )
    fig.subplots_adjust(
        left=0.06, right=0.9, bottom=0.05, top=0.94, wspace=0.28, hspace=0.18
    )
    fig.suptitle(f"Forecast Initialization: {initialization}", fontsize=24, y=0.99)
    for i, axis in enumerate(axes.flat):
        if i >= len(fields):
            axis.set_axis_off()
            continue
        artist = draw_panel(
            axis, lon, lat, fields[i], extent, province, cities, compact=True
        )
        axis.set_title(f"{times[i]:%m-%d %H:%M} BJT", fontsize=18, pad=8)
    colorbar(fig, artist, fig.add_axes((0.92, 0.18, 0.012, 0.62)))
    name = "yunnan_radar_montage.png"
    fig.savefig(output / name, dpi=dpi, bbox_inches="tight", pad_inches=0.05)
    plt.close(fig)
    return {
        "id": "airport_radar_region",
        "lead": 0,
        "lead_label": "云南区域",
        "valid_time": times[0].isoformat(),
        "time_kind": "instant",
        "file": name,
        "individual_frames": frames,
    }


def render(args: argparse.Namespace) -> int:
    source = args.input.resolve()
    signature = source_signature(source, args)
    if args.if_needed and is_current(args.output, signature):
        LOG.info("Radar images are current: %s", args.output)
        return 0
    fields, audits, digest = [], [], hashlib.sha256()
    with Dataset(source) as ds:
        if "DBZ" not in ds.variables:
            LOG.info("Source has no DBZ; skipping radar")
            return 3
        variable = ds["DBZ"]
        if variable.dimensions != ("Time", "bottom_top", "south_north", "west_east"):
            raise ValueError(f"Unexpected DBZ dimensions: {variable.dimensions}")
        units = getattr(variable, "units", "").strip().lower()
        if units not in ("", "dbz"):
            raise ValueError(f"Unexpected DBZ units: {units}")
        # The audited IAP DBZ writer uses 10*log10(Z*rho); its units attribute is blank.
        times = wrf_times(ds)
        indices = select_indices(times, args.start, args.count)
        lat, lon = np.asarray(ds["XLAT"][0]), np.asarray(ds["XLONG"][0])
        if (
            lat.shape != lon.shape
            or not np.isfinite(lat).all()
            or not np.isfinite(lon).all()
        ):
            raise ValueError("Invalid radar coordinates")
        extent = display_region(
            lat, lon, args.domain, REGION_PROFILES["yunnan"]["default_region"]
        )
        y0, y1, x0, x1 = crop_indices(lat, lon, extent)
        crop = (slice(y0, y1 + 1), slice(x0, x1 + 1))
        digest.update(lat.tobytes())
        digest.update(lon.tobytes())
        for index in indices:
            raw = np.ma.asarray(variable[index, :, :, :], dtype=float)
            if raw.shape[1:] != lat.shape:
                raise ValueError("DBZ grid differs from coordinates")
            composite, qc = composite_reflectivity(raw)
            digest.update(raw.filled(np.nan).tobytes())
            fields.append(composite[crop])
            moment = times[index].astimezone(BJT)
            audits.append(
                {"source_index": index, "valid_time": moment.isoformat(), **qc}
            )
        valid_times = [times[index].astimezone(BJT) for index in indices]
        init = times[0]
    if source_signature(source, args) != signature:
        raise RuntimeError("Source changed during radar reading; wait for completion")
    configure_matplotlib()
    plt.rcParams.update({"pdf.fonttype": 42, "ps.fonttype": 42})
    args.output.mkdir(parents=True, exist_ok=True)
    frame = save_maps(
        args.output,
        lon[crop],
        lat[crop],
        fields,
        valid_times,
        extent,
        shp_lines(args.province_shp),
        shp_lines(args.city_shp),
        init.astimezone(BJT).strftime("%Y-%m-%d %H:%M BJT"),
        args.dpi,
    )
    atomic_json(
        args.output / "production_manifest.json",
        {
            "source_signature": signature,
            "source_domain": args.domain,
            "selected_input_sha256": digest.hexdigest(),
            "source_variable": "DBZ",
            "aggregation": "vertical_maximum",
            "units": "dBZ",
            "run_time": init.isoformat(),
            "generated_at": datetime.now(UTC).isoformat(),
            "extent": list(extent),
            "qc": {
                "raw_data_modified": False,
                "min_valid_dbz": MIN_DBZ,
                "max_valid_dbz": MAX_DBZ,
                "hours": audits,
            },
            "products": [
                {
                    "id": "airport_radar",
                    "title": "模拟雷达回波",
                    "unit": "组合反射率（dBZ）",
                    "color": "#168f7a",
                    "description": "模拟组合反射率",
                    "frames": [frame],
                }
            ],
        },
    )
    LOG.info("Rendered %d radar hours from %s; WRF unchanged", len(fields), args.domain)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--province-shp", required=True, type=Path)
    parser.add_argument("--city-shp", type=Path)
    parser.add_argument("--domain", choices=("d01", "d02"), default="d01")
    parser.add_argument("--start", type=int, default=13)
    parser.add_argument("--count", type=int, default=1000)
    parser.add_argument("--dpi", type=int, default=400)
    parser.add_argument("--if-needed", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO)
    args = build_parser().parse_args(argv)
    if args.dpi < 400:
        raise ValueError("Scientific PNG output requires at least 400 dpi")
    return render(args)


if __name__ == "__main__":
    raise SystemExit(main())
