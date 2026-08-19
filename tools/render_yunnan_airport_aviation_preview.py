#!/usr/bin/env python3
"""Render one-off Yunnan airport aviation diagnostics from a completed WRF run.

This tool deliberately has no catalog, OSS, Git, or cron integration.  It is
for reviewing experimental aviation products before a separate publication
decision is made.
"""

from __future__ import print_function

import argparse
import json
import math
import struct
from datetime import datetime, timedelta, timezone
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.colors as colors
import matplotlib.pyplot as plt
import numpy as np
from matplotlib import font_manager
from matplotlib.patches import Polygon
from netCDF4 import Dataset


BJT = timezone(timedelta(hours=8))
GRAVITY = 9.80665
AIRPORTS = (
    ("Dehong Mangshi", 24.400000, 98.533300),
    ("Xishuangbanna Gasa", 21.973611, 100.762222),
    ("Puer Lancang Jingmai", 22.417778, 99.783889),
)
REGION = (97.0, 107.0, 21.0, 30.0)  # west, east, south, north


def arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--province-shp", required=True, type=Path)
    parser.add_argument("--city-shp", required=True, type=Path)
    parser.add_argument("--start", default=13, type=int)
    parser.add_argument("--count", default=12, type=int)
    return parser.parse_args()


def configure_matplotlib():
    # IAP does not have these fonts installed system-wide.  The preview wrapper
    # keeps private copies beside the runtime script so figures remain portable.
    runtime_fonts = Path(__file__).resolve().parent / "fonts"
    for font_name in ("Times New Roman.ttf", "Times New Roman Bold.ttf", "Songti.ttc"):
        font_path = runtime_fonts / font_name
        if font_path.is_file():
            font_manager.fontManager.addfont(str(font_path))
    plt.rcParams.update({
        "font.family": ["Times New Roman", "Songti SC", "DejaVu Serif"],
        "font.weight": "bold",
        "axes.labelweight": "bold",
        "axes.titleweight": "bold",
        "axes.linewidth": 1.5,
        "xtick.major.width": 1.3,
        "ytick.major.width": 1.3,
        "xtick.direction": "in",
        "ytick.direction": "in",
        "savefig.facecolor": "white",
    })


def shp_lines(path):
    """Read PolyLine/Polygon records from a simple ESRI .shp without GIS deps."""
    lines = []
    with path.open("rb") as handle:
        handle.read(100)
        while True:
            record = handle.read(8)
            if len(record) != 8:
                break
            _, content_words = struct.unpack(">2i", record)
            content = handle.read(content_words * 2)
            if len(content) < 44:
                continue
            shape_type = struct.unpack("<i", content[:4])[0]
            if shape_type not in (3, 5):
                continue
            part_count, point_count = struct.unpack("<2i", content[36:44])
            part_offset = 44
            point_offset = part_offset + 4 * part_count
            if len(content) < point_offset + 16 * point_count:
                continue
            parts = np.frombuffer(content, dtype="<i4", count=part_count, offset=part_offset)
            points = np.frombuffer(content, dtype="<f8", count=point_count * 2, offset=point_offset)
            points = points.reshape((-1, 2))
            for index, begin in enumerate(parts):
                end = parts[index + 1] if index + 1 < len(parts) else point_count
                if end - begin > 1:
                    lines.append(points[begin:end])
    return lines


def wrf_times(ds):
    raw = ds.variables["Times"][:]
    values = []
    for chars in raw:
        value = "".join(chars.astype(str)).strip()
        values.append(datetime.strptime(value, "%Y-%m-%d_%H:%M:%S").replace(tzinfo=timezone.utc))
    return values


def crop_indices(lat, lon):
    west, east, south, north = REGION
    mid_y, mid_x = lat.shape[0] // 2, lat.shape[1] // 2
    rows = np.where((lat[:, mid_x] >= south - 0.3) & (lat[:, mid_x] <= north + 0.3))[0]
    cols = np.where((lon[mid_y, :] >= west - 0.3) & (lon[mid_y, :] <= east + 0.3))[0]
    if not len(rows) or not len(cols):
        raise RuntimeError("could not determine a Yunnan crop from WRF coordinates")
    return int(rows[0]), int(rows[-1]), int(cols[0]), int(cols[-1])


def nearest(lat, lon, target_lat, target_lon):
    index = np.nanargmin((lat - target_lat) ** 2 + (lon - target_lon) ** 2)
    return tuple(int(value) for value in np.unravel_index(index, lat.shape))


def rotate(u, v, cosine, sine):
    return u * cosine - v * sine, v * cosine + u * sine


def height_interpolate(field, height, target):
    """Linearly interpolate a mass-grid field to target AGL height (metres)."""
    above = height >= target
    upper = above.argmax(axis=0)
    no_upper = ~above.any(axis=0)
    upper[no_upper] = height.shape[0] - 1
    lower = np.maximum(upper - 1, 0)
    z0 = np.take_along_axis(height, lower[None, :, :], axis=0)[0]
    z1 = np.take_along_axis(height, upper[None, :, :], axis=0)[0]
    f0 = np.take_along_axis(field, lower[None, :, :], axis=0)[0]
    f1 = np.take_along_axis(field, upper[None, :, :], axis=0)[0]
    fraction = np.divide(target - z0, z1 - z0, out=np.zeros_like(z0), where=(z1 > z0))
    value = f0 + np.clip(fraction, 0.0, 1.0) * (f1 - f0)
    return np.where(no_upper, f1, value)


def diagnostics(ds, index, row0, row1, col0, col1, cosine, sine, terrain, dx, dy):
    selection = np.s_[row0:row1 + 1, col0:col1 + 1]
    t2 = np.asarray(ds.variables["T2"][index, selection[0], selection[1]], dtype=float) - 273.15
    u10 = np.asarray(ds.variables["U10"][index, selection[0], selection[1]], dtype=float)
    v10 = np.asarray(ds.variables["V10"][index, selection[0], selection[1]], dtype=float)
    u10, v10 = rotate(u10, v10, cosine, sine)

    u = np.asarray(ds.variables["U"][index, :, row0:row1 + 1, col0:col1 + 2], dtype=float)
    v = np.asarray(ds.variables["V"][index, :, row0:row1 + 2, col0:col1 + 1], dtype=float)
    u = 0.5 * (u[:, :, :-1] + u[:, :, 1:])
    v = 0.5 * (v[:, :-1, :] + v[:, 1:, :])
    cosine_3d = cosine[None, :, :]
    sine_3d = sine[None, :, :]
    u, v = rotate(u, v, cosine_3d, sine_3d)
    geopotential = np.asarray(ds.variables["PH"][index, :, selection[0], selection[1]], dtype=float)
    geopotential += np.asarray(ds.variables["PHB"][index, :, selection[0], selection[1]], dtype=float)
    mass_height = 0.5 * (geopotential[:-1] + geopotential[1:]) / GRAVITY - terrain[None, :, :]
    u500 = height_interpolate(u, mass_height, 500.0)
    v500 = height_interpolate(v, mass_height, 500.0)
    vertical_shear = np.hypot(u500 - u10, v500 - v10)
    wind_speed = np.hypot(u10, v10)
    d_dy, d_dx = np.gradient(wind_speed, dy, dx)
    horizontal_gradient = 1000.0 * np.hypot(d_dx, d_dy)
    return t2, u10, v10, vertical_shear, horizontal_gradient


def decorate(ax, province, cities):
    west, east, south, north = REGION
    for line in province:
        ax.plot(line[:, 0], line[:, 1], color="black", linewidth=1.35, zorder=4)
    for line in cities:
        ax.plot(line[:, 0], line[:, 1], color="#404040", linewidth=0.55, zorder=4)
    # Use a real aircraft silhouette rather than a marker glyph: fonts on IAP
    # do not consistently include the airplane Unicode character or a suitable
    # icon.  This matches the outlined marker used by the airport precipitation
    # product and remains legible over every color interval.
    plane_template = np.array([
        (1.8, 0.0), (-1.1, 0.34), (-0.35, 0.08), (-1.35, 0.86),
        (0.1, 0.0), (-1.1, -0.34), (1.8, 0.0),
    ])
    for name, latitude, longitude in AIRPORTS:
        outer = plane_template * 0.135 + np.array((longitude, latitude))
        inner = plane_template * 0.103 + np.array((longitude, latitude))
        ax.add_patch(Polygon(outer, closed=True, facecolor="white", edgecolor="white", linewidth=1.2, zorder=8))
        ax.add_patch(Polygon(inner, closed=True, facecolor="#111111", edgecolor="none", zorder=9))
    ax.set_xlim(west, east)
    ax.set_ylim(south, north)
    ax.set_xticks(np.arange(98, 108, 2))
    ax.set_yticks(np.arange(22, 31, 2))
    ax.set_xticklabels(["%d°E" % value for value in ax.get_xticks()], fontsize=9)
    ax.set_yticklabels(["%d°N" % value for value in ax.get_yticks()], fontsize=9)
    ax.tick_params(top=True, right=True, pad=2)
    ax.set_aspect("equal", adjustable="box")


def map_panel(ax, lon, lat, value, u, v, bounds, cmap, label, title, province, cities, vector=True):
    norm = colors.BoundaryNorm(bounds, plt.get_cmap(cmap).N, clip=True)
    image = ax.pcolormesh(lon, lat, value, shading="auto", cmap=cmap, norm=norm, zorder=1)
    if vector:
        skip = max(1, int(max(value.shape) / 24))
        ax.quiver(lon[::skip, ::skip], lat[::skip, ::skip], u[::skip, ::skip], v[::skip, ::skip],
                  color="#202020", width=0.0026, scale=150, headwidth=3.5, zorder=5)
    decorate(ax, province, cities)
    ax.set_title(title, fontsize=11, pad=6)
    colorbar = plt.colorbar(image, ax=ax, fraction=0.040, pad=0.025, ticks=bounds)
    colorbar.ax.tick_params(labelsize=8, width=1, length=3)
    colorbar.set_label(label, fontsize=9, labelpad=4)


def hourly_figure(path, lon, lat, data, title, province, cities):
    temperature, u10, v10, vertical_shear, horizontal_gradient = data
    figure, axes = plt.subplots(1, 3, figsize=(18, 5.8), constrained_layout=True)
    map_panel(axes[0], lon, lat, temperature, u10, v10,
              [-4, 0, 4, 8, 12, 16, 20, 24, 28, 32], "turbo", "°C",
              "2 m Air Temperature and 10 m Wind", province, cities)
    map_panel(axes[1], lon, lat, vertical_shear, u10, v10,
              [0, 2, 4, 6, 8, 10, 15, 20, 25], "YlOrRd", "m s$^{-1}$",
              "10–500 m Vector Vertical Wind Shear", province, cities)
    map_panel(axes[2], lon, lat, horizontal_gradient, u10, v10,
              [0, 0.25, 0.5, 1, 1.5, 2, 3, 4, 6], "PuRd", "m s$^{-1}$ km$^{-1}$",
              "10 m Horizontal Wind-speed Gradient", province, cities)
    figure.suptitle(title, fontsize=18, y=1.02)
    figure.savefig(str(path), dpi=190, bbox_inches="tight")
    plt.close(figure)


def montage(panels, output):
    images = [plt.imread(str(path)) for path in panels]
    # Each hourly panel is a wide three-map triptych.  Match the 4-by-3 grid
    # aspect ratio so Matplotlib does not leave large blank bands between rows.
    figure, axes = plt.subplots(3, 4, figsize=(28, 7.2))
    for axis, image, path in zip(axes.flat, images, panels):
        axis.imshow(image)
        axis.set_axis_off()
    for axis in axes.flat[len(images):]:
        axis.set_axis_off()
    figure.suptitle("Yunnan Airport Aviation Diagnostics | 2026-08-18 08:00 BJT Initialization", fontsize=24, y=0.995)
    figure.subplots_adjust(left=0.01, right=0.99, bottom=0.01, top=0.97, wspace=0.015, hspace=0.035)
    figure.savefig(str(output), dpi=220)
    plt.close(figure)


def station_meteogram(output, times, station_data):
    figure, axes = plt.subplots(3, 3, figsize=(18, 10), sharex="col")
    for col, (name, values) in enumerate(station_data):
        labels = [moment.strftime("%m-%d\n%H") for moment in times]
        x = np.arange(len(times))
        axes[0, col].plot(x, values["temperature"], color="#c53b3e", linewidth=2.6, marker="o", markersize=3.5)
        axes[1, col].plot(x, values["wind"], color="#195a9e", linewidth=2.6, marker="o", markersize=3.5)
        axes[2, col].plot(x, values["vertical"], color="#ad5a11", linewidth=2.6, marker="o", markersize=3.5,
                          label="10–500 m vertical shear")
        axes[2, col].plot(x, values["horizontal"], color="#6d3d88", linewidth=2.4, marker="s", markersize=3.2,
                          label="10 m horizontal gradient")
        axes[0, col].set_title(name, fontsize=15)
        axes[2, col].set_xticks(x)
        axes[2, col].set_xticklabels(labels, fontsize=9)
        for row in range(3):
            axes[row, col].grid(axis="y", color="#d9d9d9", linewidth=0.7)
            axes[row, col].tick_params(labelsize=10, top=True, right=True)
    axes[0, 0].set_ylabel("2 m temperature (°C)", fontsize=12)
    axes[1, 0].set_ylabel("10 m wind speed (m s$^{-1}$)", fontsize=12)
    axes[2, 0].set_ylabel("Shear / gradient", fontsize=12)
    axes[2, 0].legend(loc="upper left", fontsize=8, frameon=False)
    figure.suptitle("Yunnan Airport Surface Meteorology and Low-level Wind Diagnostics (BJT)", fontsize=19)
    figure.tight_layout(rect=(0, 0, 1, 0.95))
    figure.savefig(str(output), dpi=220, bbox_inches="tight")
    plt.close(figure)


def main():
    args = arguments()
    configure_matplotlib()
    if not args.input.is_file():
        raise SystemExit("WRF file not found: %s" % args.input)
    output = args.output
    hourly = output / "hourly"
    hourly.mkdir(parents=True, exist_ok=True)
    province = shp_lines(args.province_shp)
    cities = shp_lines(args.city_shp)
    panels = []
    with Dataset(str(args.input)) as ds:
        count = len(ds.dimensions["Time"])
        end = min(args.start + args.count, count)
        if end - args.start < args.count:
            raise SystemExit("need %d valid times from T%d, found only %d" % (args.count, args.start, end - args.start))
        times = wrf_times(ds)[args.start:end]
        lat = np.asarray(ds.variables["XLAT"][0], dtype=float)
        lon = np.asarray(ds.variables["XLONG"][0], dtype=float)
        row0, row1, col0, col1 = crop_indices(lat, lon)
        selection = np.s_[row0:row1 + 1, col0:col1 + 1]
        crop_lat, crop_lon = lat[selection], lon[selection]
        cosine = np.asarray(ds.variables.get("COSALPHA", 1.0)[0, selection[0], selection[1]] if "COSALPHA" in ds.variables else np.ones_like(crop_lat), dtype=float)
        sine = np.asarray(ds.variables.get("SINALPHA", 0.0)[0, selection[0], selection[1]] if "SINALPHA" in ds.variables else np.zeros_like(crop_lat), dtype=float)
        terrain = np.asarray(ds.variables["HGT"][0, selection[0], selection[1]], dtype=float)
        dx = float(getattr(ds, "DX", 3000.0))
        dy = float(getattr(ds, "DY", 3000.0))
        station_indexes = [nearest(lat, lon, airport[1], airport[2]) for airport in AIRPORTS]
        station_values = [{"temperature": [], "wind": [], "vertical": [], "horizontal": []} for _ in AIRPORTS]
        for index, valid_time in zip(range(args.start, end), times):
            data = diagnostics(ds, index, row0, row1, col0, col1, cosine, sine, terrain, dx, dy)
            label = valid_time.astimezone(BJT).strftime("Valid %Y-%m-%d %H:00 BJT")
            panel = hourly / ("aviation_%s.png" % valid_time.astimezone(BJT).strftime("%Y%m%d_%H"))
            hourly_figure(panel, crop_lon, crop_lat, data, label, province, cities)
            panels.append(panel)
            for station, (y, x) in enumerate(station_indexes):
                station_values[station]["temperature"].append(float(data[0][y - row0, x - col0]))
                station_values[station]["wind"].append(float(math.hypot(data[1][y - row0, x - col0], data[2][y - row0, x - col0])))
                station_values[station]["vertical"].append(float(data[3][y - row0, x - col0]))
                station_values[station]["horizontal"].append(float(data[4][y - row0, x - col0]))
    montage(panels, output / "aviation_diagnostics_T13_T24_3x4.png")
    station_meteogram(output / "airport_surface_low_level_meteogram.png", [moment.astimezone(BJT) for moment in times],
                      [(airport[0], station_values[index]) for index, airport in enumerate(AIRPORTS)])
    manifest = {
        "experimental": True,
        "publishable": False,
        "source_wrfout": str(args.input),
        "initialization_bjt": "2026-08-18 08:00 BJT",
        "lead_indices": "T13–T24",
        "valid_times_bjt": [moment.astimezone(BJT).isoformat() for moment in times],
        "products": [
            "2 m air temperature with 10 m wind",
            "10–500 m vector vertical wind shear",
            "10 m horizontal wind-speed gradient",
            "airport surface and low-level meteogram",
        ],
        "airports": [airport[0] for airport in AIRPORTS],
    }
    (output / "preview_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("wrote preview to %s" % output)


if __name__ == "__main__":
    main()
