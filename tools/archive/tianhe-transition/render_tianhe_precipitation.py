#!/usr/bin/env python3
"""Render Tianhe WRF precipitation mosaics without NCL or ImageMagick."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np
import shapefile
from matplotlib.colors import BoundaryNorm, ListedColormap
from matplotlib.path import Path as MarkerPath
from netCDF4 import Dataset
from PIL import Image


BJT = timezone(timedelta(hours=8))
RAIN_BOUNDS = [0.0, 1.5, 7.0, 15.0, 40.0, 50.0, 200.0]
RAIN_CMAP = ListedColormap(
    ["#ffffff", "#6bdb66", "#40b840", "#6bade6", "#1a0dff", "#eb00eb"]
)
RAIN_NORM = BoundaryNorm(RAIN_BOUNDS, RAIN_CMAP.N, clip=True)
PANEL_DPI = 160
PANEL_SIZE = (5.4, 4.5)
MAX_AIRPORT_DISTANCE_DEG = 0.35

AIRPORTS = [
    {
        "id": "dehong_mangshi",
        "name": "德宏芒市国际机场",
        "lat": 24.400000,
        "lon": 98.533300,
    },
    {
        "id": "xishuangbanna_gasa",
        "name": "西双版纳嘎洒国际机场",
        "lat": 21.973611,
        "lon": 100.762222,
    },
    {
        "id": "puer_lancang_jingmai",
        "name": "普洱澜沧景迈机场",
        "lat": 22.417778,
        "lon": 99.783889,
    },
]

PLANE_MARKER = MarkerPath(
    np.array(
        [
            [1.8, 0.0],
            [-1.1, 0.34],
            [-0.35, 0.08],
            [-1.35, 0.86],
            [0.1, 0.0],
            [-1.1, -0.34],
            [1.8, 0.0],
        ]
    )
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("ningxia", "yunnan"), required=True)
    parser.add_argument("--wrf-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--run-id", required=True, help="UTC run id: YYYYMMDDHH")
    parser.add_argument("--city-shp", type=Path)
    parser.add_argument("--province-shp", type=Path)
    parser.add_argument("--start", type=int, default=13)
    parser.add_argument("--end", type=int, default=48)
    return parser.parse_args()


def configure_typography() -> None:
    plt.rcParams.update(
        {
            "font.family": "serif",
            "font.serif": ["Times New Roman", "Songti SC"],
            "axes.unicode_minus": False,
            "axes.linewidth": 0.8,
        }
    )


def find_wrfout(wrf_dir: Path) -> Path:
    matches = sorted(path for path in wrf_dir.glob("wrfout_d01_*") if path.is_file())
    if not matches:
        raise SystemExit(f"no wrfout_d01_* file in {wrf_dir}")
    return matches[0]


def read_times(ds: Dataset) -> list[str]:
    values = ds.variables.get("Times")
    if values is None:
        return []
    return ["".join(chars.astype(str)).strip() for chars in values[:]]


def parse_wrf_time(value: str) -> datetime | None:
    for fmt in ("%Y-%m-%d_%H:%M:%S", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(value, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    return None


def bjt_label(value: str) -> str:
    parsed = parse_wrf_time(value)
    return parsed.astimezone(BJT).strftime("%m-%d %H:00") if parsed else value


def bjt_interval(start_value: str, end_value: str) -> str:
    start = parse_wrf_time(start_value)
    end = parse_wrf_time(end_value)
    if not start or not end:
        return ""
    return f"{start.astimezone(BJT):%m-%d %H}:00-{end.astimezone(BJT):%H}:00"


def load_shapes(path: Path | None) -> list[np.ndarray]:
    if path is None or not path.is_file():
        return []

    reader = shapefile.Reader(str(path))
    lines: list[np.ndarray] = []
    for shape in reader.shapes():
        points = np.asarray(shape.points, dtype=float)
        parts = list(shape.parts) + [len(points)]
        for start, end in zip(parts, parts[1:]):
            if end - start >= 2:
                lines.append(points[start:end])
    return lines


def overlay_shapes(ax, lines: list[np.ndarray], linewidth: float) -> None:
    for line in lines:
        ax.plot(line[:, 0], line[:, 1], color="black", linewidth=linewidth, zorder=5)


def nearest_grid(
    lat2d: np.ndarray, lon2d: np.ndarray, lat: float, lon: float
) -> tuple[int, int, float]:
    distance = (lat2d - lat) ** 2 + (lon2d - lon) ** 2
    y, x = np.unravel_index(np.nanargmin(distance), distance.shape)
    return int(y), int(x), float(np.sqrt(distance[y, x]))


def airport_totals(
    ds: Dataset,
    lat2d: np.ndarray,
    lon2d: np.ndarray,
    times: list[str],
    start: int,
    end: int,
) -> dict:
    end_idx = min(end, len(ds.dimensions["Time"]) - 1)
    airports = []
    for airport in AIRPORTS:
        y, x, distance_deg = nearest_grid(lat2d, lon2d, airport["lat"], airport["lon"])
        accum = (
            ds.variables["RAINNC"][:, y, x].astype("float64")
            + ds.variables["RAINC"][:, y, x].astype("float64")
        )
        hourly = np.maximum(accum[start : end_idx + 1] - accum[start - 1 : end_idx], 0.0)
        peak_offset = int(np.argmax(hourly))
        peak_start = start - 1 + peak_offset
        peak_end = start + peak_offset
        point = {
            **airport,
            "nearest_lat": round(float(lat2d[y, x]), 6),
            "nearest_lon": round(float(lon2d[y, x]), 6),
            "nearest_distance_deg": round(distance_deg, 3),
            "grid_y": y,
            "grid_x": x,
            "max_hourly_mm": round(float(hourly[peak_offset]), 1),
            "max_hourly_start": times[peak_start] if len(times) > peak_start else "",
            "max_hourly_end": times[peak_end] if len(times) > peak_end else "",
            "max_hourly_time": bjt_interval(
                times[peak_start] if len(times) > peak_start else "",
                times[peak_end] if len(times) > peak_end else "",
            ),
        }
        if distance_deg > MAX_AIRPORT_DISTANCE_DEG:
            airports.append(
                {
                    **point,
                    "status": "outside_domain",
                    "note": "机场点超出当前 WORK_yn d01 网格覆盖范围",
                }
            )
        else:
            airports.append(
                {
                    **point,
                    "status": "ok",
                    "total_mm": round(float(np.sum(hourly)), 1),
                }
            )

    return {
        "lead_start": start,
        "lead_end": end_idx,
        "unit": "mm",
        "valid_time_start": times[start - 1] if len(times) > start - 1 else "",
        "valid_time_end": times[end_idx] if len(times) > end_idx else "",
        "airports": airports,
    }


def draw_airports(ax) -> None:
    lons = [airport["lon"] for airport in AIRPORTS]
    lats = [airport["lat"] for airport in AIRPORTS]
    ax.scatter(
        lons,
        lats,
        marker=PLANE_MARKER,
        s=850,
        facecolor="white",
        edgecolor="white",
        linewidth=0,
        zorder=7,
    )
    ax.scatter(
        lons,
        lats,
        marker=PLANE_MARKER,
        s=540,
        facecolor="#111111",
        edgecolor="#111111",
        linewidth=0,
        zorder=8,
    )


def draw_panel(
    output: Path,
    rain: np.ndarray,
    lon2d: np.ndarray,
    lat2d: np.ndarray,
    title: str,
    extent: tuple[float, float, float, float],
    city_lines: list[np.ndarray],
    province_lines: list[np.ndarray],
    show_airports: bool,
) -> None:
    fig, ax = plt.subplots(figsize=PANEL_SIZE, dpi=PANEL_DPI)
    masked = np.ma.masked_where(rain < 0.01, rain)
    image = ax.pcolormesh(
        lon2d,
        lat2d,
        masked,
        cmap=RAIN_CMAP,
        norm=RAIN_NORM,
        shading="auto",
        zorder=1,
    )
    ax.set_xlim(extent[0], extent[1])
    ax.set_ylim(extent[2], extent[3])
    ax.set_xticks(np.arange(np.ceil(extent[0]), np.floor(extent[1]) + 1, 1.0))
    ax.set_yticks(np.arange(np.ceil(extent[2]), np.floor(extent[3]) + 1, 1.0))
    ax.tick_params(labelsize=7, width=0.8)
    ax.grid(color="#777777", linewidth=0.25, alpha=0.35, zorder=2)
    overlay_shapes(ax, city_lines, 0.45)
    overlay_shapes(ax, province_lines, 1.15)
    if show_airports:
        draw_airports(ax)
    colorbar = fig.colorbar(
        image,
        ax=ax,
        fraction=0.043,
        pad=0.025,
        boundaries=RAIN_BOUNDS,
        ticks=RAIN_BOUNDS[:-1],
    )
    colorbar.ax.tick_params(labelsize=6, length=1.5)
    fig.text(0.5, 0.975, title, ha="center", va="top", fontsize=13, color="black")
    fig.subplots_adjust(left=0.09, right=0.91, bottom=0.10, top=0.93)
    fig.savefig(output, facecolor="white")
    plt.close(fig)


def make_mosaic(panel_paths: list[Path], output: Path) -> None:
    with Image.open(panel_paths[0]) as first:
        tile_width, tile_height = first.size
    canvas = Image.new("RGB", (tile_width * 6, tile_height * 6), "white")
    for index, path in enumerate(panel_paths):
        with Image.open(path) as image:
            x = (index % 6) * tile_width
            y = (index // 6) * tile_height
            canvas.paste(image.convert("RGB"), (x, y))
    temporary = output.with_suffix(".tmp.png")
    canvas.save(temporary, format="PNG", optimize=True)
    temporary.replace(output)


def output_name(mode: str, run_id: str) -> str:
    parsed = datetime.strptime(run_id, "%Y%m%d%H")
    stamp = parsed.strftime("%Y-%m-%d_%H_00")
    if mode == "ningxia":
        return f"Precip_hourly_WRF_Ningxia_T13_T48_InitUTC_{stamp}_combined_overview_6x6_grid.png"
    return f"Precip_hourly_WRF_YunnanAirports_T13_T48_InitUTC_{stamp}_combined_overview_6x6_grid.png"


def render(args: argparse.Namespace) -> None:
    configure_typography()
    wrfout = find_wrfout(args.wrf_dir)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    panel_dir = args.output_dir / ".panels"
    shutil.rmtree(panel_dir, ignore_errors=True)
    panel_dir.mkdir(parents=True)

    if args.mode == "ningxia":
        extent = (104.0, 107.8, 35.0, 39.7)
    else:
        extent = (97.0, 106.7, 21.0, 29.7)
    city_lines = load_shapes(args.city_shp)
    province_lines = load_shapes(args.province_shp)
    panel_paths: list[Path] = []

    with Dataset(wrfout) as ds:
        time_count = len(ds.dimensions["Time"])
        end = min(args.end, time_count - 1)
        if end - args.start + 1 != 36:
            raise SystemExit(
                f"expected 36 fields from T{args.start:02d} to T{args.end:02d}; "
                f"WRF file provides T{end:02d}"
            )
        lat2d = np.asarray(ds.variables["XLAT"][0, :, :], dtype=float)
        lon2d = np.asarray(ds.variables["XLONG"][0, :, :], dtype=float)
        times = read_times(ds)

        for index, time_index in enumerate(range(args.start, end + 1), start=1):
            rain = np.asarray(
                ds.variables["RAINNC"][time_index, :, :]
                + ds.variables["RAINC"][time_index, :, :]
                - ds.variables["RAINNC"][time_index - 1, :, :]
                - ds.variables["RAINC"][time_index - 1, :, :],
                dtype=float,
            )
            rain = np.maximum(rain, 0.0)
            end_time = times[time_index] if len(times) > time_index else f"T{time_index:02d}"
            panel_path = panel_dir / f"panel_{index:02d}.png"
            draw_panel(
                panel_path,
                rain,
                lon2d,
                lat2d,
                bjt_label(end_time),
                extent,
                city_lines,
                province_lines,
                args.mode == "yunnan",
            )
            panel_paths.append(panel_path)

        output = args.output_dir / output_name(args.mode, args.run_id)
        make_mosaic(panel_paths, output)
        os.utime(output, (wrfout.stat().st_atime, wrfout.stat().st_mtime))

        if args.mode == "yunnan":
            totals = airport_totals(ds, lat2d, lon2d, times, args.start, end)
            totals["source_wrfout"] = str(wrfout)
            (args.output_dir / "airport_precip_totals.json").write_text(
                json.dumps(totals, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )

    shutil.rmtree(panel_dir, ignore_errors=True)
    print(output)


def main() -> None:
    render(parse_args())


if __name__ == "__main__":
    main()
