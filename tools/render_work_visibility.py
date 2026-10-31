#!/usr/bin/env python3
"""Plot a selected WRF visibility field with display-only QC; never modify WRF."""

from __future__ import annotations

import argparse
import hashlib
import json
import logging
import math
import os
from datetime import UTC, datetime, timedelta, timezone
from itertools import pairwise
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib import colors, font_manager
from matplotlib.axes import Axes
from matplotlib.collections import QuadMesh
from matplotlib.figure import Figure
from netCDF4 import Dataset
from render_yunnan_airport_aviation_preview import (
    REGION_PROFILES,
    cn_sized_props,
    configure_matplotlib,
    decorate,
    display_region,
    line_intersects_region,
    shp_lines,
    wrf_times,
)

LOG = logging.getLogger(__name__)
BJT = timezone(timedelta(hours=8))
QC_VERSION = "raw_vis_qc_v1"
MAX_VISIBILITY_M = 100000.0  # Provisional QC threshold, not a weather standard.
FOG_COLORS = ["#8B4513", "#E31A1C", "#FF8C1A", "#FFD32A", "#FFF55C", "#FFFFFF"]
INVALID_COLOR = "#ffffff"
BIN_EDGES = np.array([50, 100, 200, 500, 1000], dtype=float)
BIN_LABELS = ["<50", "50-100", "100-200", "200-500", "500-1000", ">=1000"]
REGION = (104.0, 107.8, 35.0, 39.7)


def quality_control(raw: np.ndarray) -> tuple[np.ma.MaskedArray, dict]:
    """Return masked lowest-layer VIS in m and disjoint counts; raw is unchanged."""
    values = np.ma.asarray(raw, dtype=np.float64)
    if values.ndim != 2 or min(values.shape) < 3:
        raise ValueError("VIS must be a 2-D grid with an interior")
    data = values.filled(np.nan)
    boundary = np.zeros(data.shape, dtype=bool)
    boundary[[0, -1], :] = True
    boundary[:, [0, -1]] = True
    missing = ~np.isfinite(data) | np.ma.getmaskarray(values)
    nonpositive = np.isfinite(data) & (data <= 0)
    excessive = np.isfinite(data) & (data > MAX_VISIBILITY_M)
    invalid = boundary | missing | nonpositive | excessive
    interior = ~boundary
    stats = {
        "total_cells": int(data.size),
        "boundary_cells": int(boundary.sum()),
        "missing_interior": int((missing & interior).sum()),
        "nonpositive_interior": int((nonpositive & interior).sum()),
        "over_100km_interior": int((excessive & interior).sum()),
        "valid_cells": int((~invalid).sum()),
        "invalid_fraction": float(invalid.mean()),
        "suspect_interior_fraction": float((invalid & interior).sum() / interior.sum()),
    }
    if not stats["valid_cells"]:
        raise ValueError("VIS has no valid interior cells; withholding this product")
    return np.ma.array(data, mask=invalid, copy=True), stats


def categories(values: np.ma.MaskedArray) -> np.ndarray:
    """Six FOG categories plus a distinct invalid category; no interpolation."""
    codes = np.digitize(values.filled(0), BIN_EDGES).astype(np.uint8)
    codes[np.ma.getmaskarray(values)] = 6
    return codes


def select_indices(times: list[datetime], start: int, count: int) -> list[int]:
    if not times or any(b <= a for a, b in pairwise(times)):
        raise ValueError("WRF Times are empty, repeated, or out of order")
    if start < 13 or count < 1:
        raise ValueError(
            "Visibility starts after 12-hour spin-up; count must be positive"
        )
    selected = [
        i for i, time in enumerate(times) if time >= times[0] + timedelta(hours=start)
    ][:count]
    if not selected:
        raise ValueError("No post-spin-up VIS times available")
    return selected


def atomic_json(path: Path, value: dict) -> None:
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_text(
        json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    os.replace(temporary, path)


def source_signature(source: Path, args: argparse.Namespace) -> dict:
    stat = source.stat()
    shared = Path(__file__).with_name("render_yunnan_airport_aviation_preview.py")
    return {
        "source": str(source.resolve()),
        "size": stat.st_size,
        "mtime_ns": stat.st_mtime_ns,
        "qc_version": QC_VERSION,
        "code_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "map_helpers_sha256": hashlib.sha256(shared.read_bytes()).hexdigest(),
        "province_sha256": hashlib.sha256(args.province_shp.read_bytes()).hexdigest(),
        "county_sha256": (
            hashlib.sha256(args.county_shp.read_bytes()).hexdigest()
            if args.county_shp
            else None
        ),
        "start": args.start,
        "count": args.count,
        "dpi": args.dpi,
        "variable": getattr(args, "variable", "VIS_MIN"),
        "profile": getattr(args, "profile", "ningxia"),
        "domain": getattr(args, "domain", "d01"),
        "area": getattr(args, "area", "regional"),
    }


def is_current(output: Path, signature: dict) -> bool:
    manifest_path = output / "production_manifest.json"
    if not manifest_path.is_file():
        return False
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        LOG.warning("Invalid cached manifest; rebuilding %s", manifest_path)
        return False
    if manifest.get("source_signature") != signature:
        return False
    frames = [
        frame for product in manifest.get("products", []) for frame in product["frames"]
    ]
    assets = frames + [
        panel for frame in frames for panel in frame["individual_frames"]
    ]
    return bool(assets) and all((output / f["file"]).is_file() for f in assets)


def draw_panel(
    axis: Axes,
    lon: np.ndarray,
    lat: np.ndarray,
    field: np.ndarray,
    extent: tuple[float, float, float, float],
    province: list,
    counties: list,
    tick_size: int = 18,
    omit_104_label: bool = False,
    airports: tuple = (),
    xinjiang_ticks: bool = False,
) -> QuadMesh:
    """Draw categorical cells and existing map boundaries on an Axes."""
    palette = colors.ListedColormap(FOG_COLORS)
    palette.set_bad(INVALID_COLOR)
    norm = colors.BoundaryNorm(np.arange(7) - 0.5, palette.N)
    field = np.ma.masked_equal(field, 6)
    artist = axis.pcolormesh(
        lon, lat, field, cmap=palette, norm=norm, shading="nearest", rasterized=True
    )
    national = extent[1] - extent[0] > 20
    decorate(
        axis,
        [] if national else province,
        counties,
        extent,
        airports,
        tick_size=tick_size,
    )
    if national:
        for line in province:
            if line_intersects_region(line, extent):
                axis.plot(
                    line[:, 0], line[:, 1], color="black", linewidth=1.1, zorder=6
                )
        xticks = np.arange(math.ceil(extent[0] / 20) * 20, extent[1] + 0.01, 20)
        yticks = np.arange(math.ceil(extent[2] / 10) * 10, extent[3] + 0.01, 10)
    else:
        xticks = np.arange(math.ceil(extent[0]), extent[1] + 0.01)
        yticks = np.arange(math.ceil(extent[2]), extent[3] + 0.01)
    if xinjiang_ticks:
        xticks = np.arange(
            72 + math.ceil((extent[0] - 72) / 8) * 8, extent[1] + 0.01, 8
        )
        yticks = np.arange(
            34 + math.ceil((extent[2] - 34) / 4) * 4, extent[3] + 0.01, 4
        )
    labels = axis.set_xticks(
        xticks,
        ["" if omit_104_label and x == 104 else f"{x:g}°E" for x in xticks],
    )
    axis.set_yticks(yticks, [f"{y:g}°N" for y in yticks])
    if labels:
        for label in axis.get_xticklabels():
            label.set_horizontalalignment("center")
        if np.isclose(xticks[0], extent[0]):
            axis.get_xticklabels()[0].set_horizontalalignment("left")
        if np.isclose(xticks[-1], extent[1]):
            axis.get_xticklabels()[-1].set_horizontalalignment("right")
    axis.tick_params(width=3, length=8, top=True, right=True)
    return artist


def add_colorbar(figure: Figure, artist: QuadMesh, axis: Axes, size: int = 16) -> None:
    colorbar = figure.colorbar(
        artist, cax=axis, ticks=np.arange(6), orientation="vertical"
    )
    colorbar.ax.set_yticklabels(BIN_LABELS, **cn_sized_props(size))
    colorbar.ax.tick_params(width=2, length=5)
    colorbar.set_label("能见度（米）", **cn_sized_props(size + 2))


def save_maps(
    output: Path,
    lon: np.ndarray,
    lat: np.ndarray,
    fields: list[np.ndarray],
    times: list[datetime],
    extent: tuple[float, float, float, float],
    province: list,
    counties: list,
    area: str,
    dpi: int,
    initialization: str,
) -> dict:
    """Write hourly and montage rasters with instantaneous BJT timestamps."""
    frames = []
    airports = REGION_PROFILES.get(area.split("_")[0], {}).get("airports", ())
    ratio = (extent[3] - extent[2]) / (extent[1] - extent[0])
    for field, time in zip(fields, times):
        filename = f"{area}_{time:%Y%m%d%H}_BJT.png"
        figure = plt.figure(figsize=(12, max(5, 9.6 * ratio + 1.1)))
        grid = figure.add_gridspec(
            1,
            2,
            width_ratios=(30, 1),
            left=0.07,
            right=0.87,
            bottom=0.08,
            top=0.91,
            wspace=0.08,
        )
        axis = figure.add_subplot(grid[0, 0])
        artist = draw_panel(
            axis,
            lon,
            lat,
            field,
            extent,
            province,
            counties,
            airports=airports,
            xinjiang_ticks=area == "xinjiang",
        )
        axis.set_title(f"{time:%m-%d %H:%M} BJT", fontsize=24, pad=10)
        add_colorbar(figure, artist, figure.add_subplot(grid[0, 1]))
        figure.savefig(output / filename, dpi=dpi, bbox_inches="tight", pad_inches=0.05)
        plt.close(figure)
        frames.append(
            {
                "id": f"visibility_{area}_{time:%Y%m%d%H}",
                "lead_label": f"{time:%m-%d %H:%M} BJT",
                "valid_time": time.isoformat(),
                "time_kind": "instant",
                "file": filename,
            }
        )
    columns = min(4, len(fields))
    rows = math.ceil(len(fields) / columns)
    width = 4.7 * columns + 1.7
    height = max(4, rows * (4.1 * ratio + 0.85) + 0.7)
    figure, axes = plt.subplots(rows, columns, figsize=(width, height), squeeze=False)
    figure.subplots_adjust(
        left=0.055, right=0.88, bottom=0.05, top=0.94, wspace=0.30, hspace=0.32
    )
    figure.suptitle(f"Forecast Initialization: {initialization}", fontsize=22, y=0.985)
    for i, axis in enumerate(axes.flat):
        if i >= len(fields):
            axis.set_axis_off()
            continue
        artist = draw_panel(
            axis,
            lon,
            lat,
            fields[i],
            extent,
            province,
            counties,
            omit_104_label=area == "ningxia",
            airports=airports,
            xinjiang_ticks=area == "xinjiang",
        )
        axis.set_title(f"{times[i]:%m-%d %H:%M} BJT", fontsize=16, pad=7)
    add_colorbar(figure, artist, figure.add_axes((0.9, 0.20, 0.012, 0.60)))
    name = f"visibility_{area}_montage.png"
    figure.savefig(output / name, dpi=dpi, bbox_inches="tight", pad_inches=0.05)
    plt.close(figure)
    return {
        "id": f"visibility_{area}",
        "lead": 1 if area == "central_east" else 0,
        "lead_label": {
            "ningxia": "宁夏区域",
            "central_east": "中国中东部",
            "yunnan": "云南区域",
            "xinjiang": "新疆区域",
            "yunnan_wide": "中国西南部",
            "xinjiang_wide": "中国西北部",
        }[area],
        "valid_time": times[0].isoformat(),
        "time_kind": "instant",
        "file": name,
        "individual_frames": frames,
    }


def visibility_variable(dataset: Dataset, name: str):
    """Validate a metre-valued 3-D field; fallback is allowed only in auto mode."""
    if name == "auto":
        name = "VIS_MIN" if "VIS_MIN" in dataset.variables else "VIS"
    if name not in dataset.variables:
        return None
    variable = dataset[name]
    if variable.dimensions != ("Time", "bottom_top", "south_north", "west_east"):
        raise ValueError(f"Unexpected {name} dimensions: {variable.dimensions}")
    if getattr(variable, "units", "").strip().lower() not in {"m", "meter", "meters"}:
        raise ValueError(f"{name} units must be explicitly metres")
    if variable.shape[1] < 1:
        raise ValueError(f"{name} has no vertical levels")
    return variable


def render(args: argparse.Namespace) -> int:
    source = args.input.resolve()
    signature = source_signature(source, args)
    if args.if_needed and is_current(args.output, signature):
        LOG.info("Visibility output is current: %s", args.output)
        return 0
    args.output.mkdir(parents=True, exist_ok=True)
    configure_matplotlib()
    # Local preview uses macOS fonts; production uses runtime/fonts.
    for name in ("Times New Roman.ttf", "Times New Roman Bold.ttf", "Songti.ttc"):
        path = Path("/System/Library/Fonts/Supplemental") / name
        if path.is_file():
            font_manager.fontManager.addfont(str(path))
    plt.rcParams.update({"pdf.fonttype": 42, "ps.fonttype": 42})
    province = shp_lines(args.province_shp)
    counties = shp_lines(args.county_shp)
    digest = hashlib.sha256()
    with Dataset(source) as dataset:
        variable = visibility_variable(dataset, args.variable)
        if variable is None:
            LOG.info(
                "No %s in source; no visibility product: %s", args.variable, source
            )
            return 3
        selected_variable = variable.name
        times = wrf_times(dataset)
        indices = select_indices(times, args.start, args.count)
        lat = np.asarray(dataset["XLAT"][0], dtype=float)
        lon = np.asarray(dataset["XLONG"][0], dtype=float)
        if (
            lat.shape != lon.shape
            or not np.isfinite(lat).all()
            or not np.isfinite(lon).all()
        ):
            raise ValueError("Invalid WRF coordinates")
        digest.update(lat.tobytes())
        digest.update(lon.tobytes())
        fields, audit = [], []
        for index in indices:
            raw = np.ma.asarray(variable[index, 0, :, :], dtype=float)
            if raw.shape != lat.shape:
                raise ValueError("VIS and coordinate shapes differ")
            clean, stats = quality_control(raw)
            digest.update(raw.filled(np.nan).tobytes())
            digest.update(np.ma.getmaskarray(raw).tobytes())
            moment = times[index].astimezone(BJT)
            digest.update(moment.isoformat().encode())
            audit.append(
                {"source_index": index, "valid_time": moment.isoformat(), **stats}
            )
            fields.append(categories(clean))
        valid_times = [times[i].astimezone(BJT) for i in indices]
        init_time = times[0].isoformat()
    # A live source is only useful for isolated previews, never a publication.
    if source_signature(source, args) != signature:
        raise RuntimeError(
            "WRF source changed during reading; retry after model completion"
        )
    national = (
        math.floor(lon.min()),
        min(150, math.ceil(lon.max())),
        math.floor(lat.min()),
        math.ceil(lat.max()),
    )
    areas = (
        ("ningxia", REGION, counties),
        ("central_east", national, []),
    )
    if args.profile != "ningxia":
        extent = display_region(
            lat, lon, args.domain, REGION_PROFILES[args.profile]["default_region"]
        )
        areas = ((args.profile, extent, counties),)
        if getattr(args, "area", "regional") == "wide":
            extent = (
                math.floor(lon.min()),
                math.ceil(lon.max()),
                math.floor(lat.min()),
                math.ceil(lat.max()),
            )
            areas = ((args.profile + "_wide", extent, []),)
    frames = []
    for area, extent, lines in areas:
        inside = (
            (lon >= extent[0])
            & (lon <= extent[1])
            & (lat >= extent[2])
            & (lat <= extent[3])
        )
        if not inside.any():
            raise ValueError(f"Source domain does not cover {area}")
        locations = np.argwhere(inside)
        lower = np.maximum(locations.min(axis=0) - 1, 0)
        upper = np.minimum(locations.max(axis=0) + 2, lat.shape)
        crop = (slice(lower[0], upper[0]), slice(lower[1], upper[1]))
        frames.append(
            save_maps(
                args.output,
                lon[crop],
                lat[crop],
                [field[crop] for field in fields],
                valid_times,
                extent,
                province,
                lines,
                area,
                args.dpi,
                datetime.fromisoformat(init_time)
                .astimezone(BJT)
                .strftime("%Y-%m-%d %H:%M BJT"),
            )
        )
    manifest = {
        "source_signature": signature,
        "selected_input_sha256": digest.hexdigest(),
        "source_variable": selected_variable,
        "source_vertical_level": 0,
        "units": "m",
        "run_time": init_time,
        "generated_at": datetime.now(UTC).isoformat(),
        "qc": {
            "version": QC_VERSION,
            "max_valid_m": MAX_VISIBILITY_M,
            "raw_data_modified": False,
            "hours": audit,
        },
        "products": [
            {
                "id": {
                    "ningxia": "ningxia_visibility",
                    "yunnan": "airport_visibility",
                    "xinjiang": "xinjiang_visibility",
                }[args.profile],
                "title": "能见度",
                "unit": f"最低模式层 {selected_variable}（米）",
                "color": "#0f68c8",
                "description": "" if args.profile == "yunnan" else "能见度",
                "frames": frames,
            }
        ],
    }
    atomic_json(args.output / "production_manifest.json", manifest)
    LOG.info("Rendered %d VIS times; raw WRF unchanged", len(valid_times))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--province-shp", required=True, type=Path)
    parser.add_argument("--county-shp", type=Path)
    parser.add_argument(
        "--variable", choices=("VIS_MIN", "VIS", "auto"), default="VIS_MIN"
    )
    parser.add_argument(
        "--profile", choices=("ningxia", "yunnan", "xinjiang"), default="ningxia"
    )
    parser.add_argument("--domain", choices=("d01", "d02"), default="d01")
    parser.add_argument("--area", choices=("regional", "wide"), default="regional")
    parser.add_argument("--start", type=int, default=13)
    parser.add_argument("--count", type=int, default=36)
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
