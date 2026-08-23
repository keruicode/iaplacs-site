#!/usr/bin/env python3
"""Render Yunnan airport aviation diagnostics from a completed WRF run.

The same renderer supports a one-off preview and the production WORK_yn
publisher.  Publication, OSS upload, and Git operations remain in the shell
publisher so rendering stays deterministic and independently testable.
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
from matplotlib.font_manager import FontProperties
from matplotlib.patches import Polygon
from netCDF4 import Dataset


BJT = timezone(timedelta(hours=8))
GRAVITY = 9.80665
AIRPORTS = (
    ("德宏芒市国际机场", 24.400000, 98.533300),
    ("西双版纳嘎洒国际机场", 21.973611, 100.762222),
    ("普洱澜沧景迈机场", 22.417778, 99.783889),
)
REGION = (97.0, 107.0, 21.0, 30.0)  # west, east, south, north
CHINESE_FONT = None

PLOT_PRODUCTS = (
    ("temperature", "气温", "温度（℃）"),
    ("wind", "风场", "风速（米/秒）"),
    ("vertical_shear", "10-500米垂直风切", "风切（米/秒）"),
    ("horizontal_gradient", "10米水平风速梯度", "梯度（米/秒/千米）"),
)

PRODUCTS = (
    ("temperature", "气温", "温度（℃）", ("temperature",)),
    ("wind", "风场", "风场诊断", ("wind", "vertical_shear", "horizontal_gradient")),
)


def arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--province-shp", required=True, type=Path)
    parser.add_argument("--city-shp", required=True, type=Path)
    parser.add_argument("--start", default=13, type=int)
    parser.add_argument("--count", default=12, type=int)
    parser.add_argument("--run-id", default="20260818_00")
    parser.add_argument("--production", action="store_true")
    return parser.parse_args()


def configure_matplotlib():
    global CHINESE_FONT
    # IAP does not have these fonts installed system-wide.  The preview wrapper
    # keeps private copies beside the runtime script so figures remain portable.
    script_dir = Path(__file__).resolve().parent
    font_roots = (script_dir / "fonts", script_dir.parent / "fonts")
    for font_name in ("Times New Roman.ttf", "Times New Roman Bold.ttf", "Songti.ttc"):
        for font_root in font_roots:
            font_path = font_root / font_name
            if not font_path.is_file():
                continue
            font_manager.fontManager.addfont(str(font_path))
            if font_name == "Songti.ttc":
                CHINESE_FONT = FontProperties(fname=str(font_path))
            break
    plt.rcParams.update({
        "font.family": ["Times New Roman", "Songti SC"],
        "font.weight": "bold",
        "axes.labelweight": "bold",
        "axes.titleweight": "bold",
        "axes.linewidth": 3.0,
        "xtick.major.width": 2.6,
        "ytick.major.width": 2.6,
        "xtick.major.size": 7.0,
        "ytick.major.size": 7.0,
        "xtick.direction": "in",
        "ytick.direction": "in",
        "savefig.facecolor": "white",
    })


def cn_props():
    return {"fontproperties": CHINESE_FONT} if CHINESE_FONT else {}


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


def decorate(ax, province, cities, show_x=True, show_y=True, tick_size=12, plane_scale=0.120):
    west, east, south, north = REGION
    for line in cities:
        ax.plot(line[:, 0], line[:, 1], color="#404040", linewidth=1.6, zorder=4)
    # Draw the province outline last so coincident city segments cannot cover
    # it.  The 5 pt stroke remains distinct after the 6000 px WebP resize and
    # matches the visual hierarchy of the precipitation products.
    for line in province:
        ax.plot(line[:, 0], line[:, 1], color="black", linewidth=5.0, zorder=5)
    # Use a real aircraft silhouette rather than a marker glyph: fonts on IAP
    # do not consistently include the airplane Unicode character or a suitable
    # icon.  This matches the outlined marker used by the airport precipitation
    # product and remains legible over every color interval.
    plane_template = np.array([
        (1.8, 0.0), (-1.1, 0.34), (-0.35, 0.08), (-1.35, 0.86),
        (0.1, 0.0), (-1.1, -0.34), (1.8, 0.0),
    ])
    for name, latitude, longitude in AIRPORTS:
        outer = plane_template * plane_scale + np.array((longitude, latitude))
        inner = plane_template * (plane_scale * 0.78) + np.array((longitude, latitude))
        ax.add_patch(Polygon(outer, closed=True, facecolor="white", edgecolor="white", linewidth=1.15, zorder=8))
        ax.add_patch(Polygon(inner, closed=True, facecolor="#050505", edgecolor="#050505", linewidth=0.45, zorder=9))
    ax.set_xlim(west, east)
    ax.set_ylim(south, north)
    ax.set_xticks(np.arange(98, 108, 2))
    ax.set_yticks(np.arange(22, 31, 2))
    ax.set_xticklabels(["%d°E" % value for value in ax.get_xticks()], fontsize=tick_size, fontweight="bold")
    ax.set_yticklabels(["%d°N" % value for value in ax.get_yticks()], fontsize=tick_size, fontweight="bold")
    for spine in ax.spines.values():
        spine.set_linewidth(3.0)
    ax.tick_params(top=True, right=True, pad=3, labeltop=False, labelright=False,
                   width=2.6, length=7.0)
    ax.tick_params(labelbottom=show_x, labelleft=show_y)
    ax.set_aspect("equal", adjustable="box")


def ec_temperature_cmap():
    return colors.ListedColormap([
        "#313695", "#4575b4", "#74add1", "#abd9e9", "#e0f3f8", "#ffffbf",
        "#fee090", "#fdae61", "#f46d43", "#d73027", "#a50026", "#7f0000",
    ])


def ec_wind_cmap():
    return colors.ListedColormap([
        "#ffffff", "#eaf4ff", "#b9dcf4", "#73b9dc", "#2c8cbe",
        "#35b779", "#8fd34e", "#f4e85b", "#f6a33c", "#d73027",
    ])


def product_field(kind, data):
    temperature, u10, v10, vertical_shear, horizontal_gradient = data
    if kind == "temperature":
        return temperature, [-30, -20, -10, 0, 5, 10, 15, 20, 25, 30, 35, 40, 50], ec_temperature_cmap()
    if kind == "wind":
        return np.hypot(u10, v10), [0, 2, 4, 6, 8, 10, 12, 15, 20, 25, 30], ec_wind_cmap()
    if kind == "vertical_shear":
        return vertical_shear, [0, 2, 4, 6, 8, 10, 12, 15, 20, 25, 30], plt.get_cmap("YlOrRd", 10)
    return horizontal_gradient, [0, 0.1, 0.2, 0.3, 0.5, 0.75, 1, 1.5, 2, 3], plt.get_cmap("PuBuGn", 9)


def plot_product(ax, lon, lat, data, kind, province, cities, **decorate_options):
    value, bounds, cmap = product_field(kind, data)
    norm = colors.BoundaryNorm(bounds, cmap.N, clip=True)
    image = ax.pcolormesh(lon, lat, value, shading="auto", cmap=cmap, norm=norm, zorder=1)
    target_vectors = decorate_options.pop("target_vectors", 30)
    if kind == "wind":
        _, u10, v10, _, _ = data
        skip = max(1, int(max(value.shape) / target_vectors))
        wind_u = u10[::skip, ::skip]
        wind_v = v10[::skip, ::skip]
        wind_lon = lon[::skip, ::skip]
        wind_lat = lat[::skip, ::skip]
        # Matplotlib renders sub-half-barb wind speeds as empty circles.  Omit
        # those calm vectors; the discrete wind-speed fill still shows them.
        active = np.hypot(wind_u, wind_v) >= 2.5
        ax.barbs(wind_lon[active], wind_lat[active], wind_u[active], wind_v[active],
                 length=5.8 if target_vectors >= 30 else 4.8,
                 linewidth=1.70, barbcolor="#17324d", flagcolor="#17324d", zorder=6)
    decorate(ax, province, cities, **decorate_options)
    return image, bounds


def style_colorbar(colorbar, bounds, unit, label_size=14, tick_size=12, horizontal=False):
    colorbar.set_ticks(bounds)
    colorbar.ax.tick_params(labelsize=tick_size, width=1.6, length=4, pad=3)
    for label in colorbar.ax.get_xticklabels() + colorbar.ax.get_yticklabels():
        label.set_fontweight("bold")
    if horizontal:
        colorbar.set_label(unit, fontsize=label_size, labelpad=7, **cn_props())
    else:
        colorbar.set_label(unit, fontsize=label_size, labelpad=9, **cn_props())


def valid_interval(moment):
    start = moment.astimezone(BJT)
    end = start + timedelta(hours=1)
    return "%s-%s BJT" % (start.strftime("%m-%d %H:%M"), end.strftime("%H:%M"))


def single_map(path, lon, lat, data, kind, product_title, unit, valid_time, province, cities):
    figure = plt.figure(figsize=(12.0, 9.2), layout="constrained")
    grid = figure.add_gridspec(1, 2, width_ratios=(32, 1), wspace=0.04)
    axis = figure.add_subplot(grid[0, 0])
    color_axis = figure.add_subplot(grid[0, 1])
    image, bounds = plot_product(
        axis, lon, lat, data, kind, province, cities,
        tick_size=20, plane_scale=0.250, target_vectors=32,
    )
    figure.suptitle(valid_time, fontsize=28, fontweight="bold", y=0.985, **cn_props())
    colorbar = figure.colorbar(image, cax=color_axis, orientation="vertical")
    style_colorbar(colorbar, bounds, unit, label_size=16, tick_size=13)
    figure.savefig(str(path), dpi=420, bbox_inches="tight", pad_inches=0.04)
    plt.close(figure)


def montage(time_steps, output, lon, lat, kind, product_title, unit, province, cities, initialization_label):
    columns = 4
    rows = max(1, int(math.ceil(len(time_steps) / float(columns))))
    figure, axes = plt.subplots(rows, columns, figsize=(18.2, max(15.1, 5.0 * rows)))
    axes = np.asarray(axes).reshape(-1)
    figure.subplots_adjust(left=0.085, right=0.875, bottom=0.075, top=0.885, wspace=0.105, hspace=0.165)
    image = None
    bounds = None
    for index, axis in enumerate(axes):
        if index >= len(time_steps):
            axis.set_axis_off()
            continue
        data, valid_time = time_steps[index]
        image, bounds = plot_product(
            axis, lon, lat, data, kind, province, cities,
            show_x=index // columns == rows - 1,
            show_y=index % 4 == 0,
            tick_size=19,
            plane_scale=0.180,
            target_vectors=18,
        )
        axis.set_title(valid_interval(valid_time), fontsize=18, pad=5, fontweight="bold")
    figure.suptitle("Forecast Initialization: %s" % initialization_label,
                    fontsize=25, y=0.958, fontweight="bold")
    color_axis = figure.add_axes([0.905, 0.155, 0.018, 0.67])
    colorbar = figure.colorbar(image, cax=color_axis, orientation="vertical")
    style_colorbar(colorbar, bounds, unit, label_size=16, tick_size=13)
    figure.savefig(str(output), dpi=420, bbox_inches="tight", pad_inches=0.03)
    plt.close(figure)


def station_meteogram(output, times, station_data, selected_keys):
    x = np.arange(len(times))
    labels = [moment.strftime("%m-%d\n%H时") for moment in times]
    all_series = (
        ("temperature", "2米气温", "2米气温（℃）"),
        ("wind", "10米风场", "10米风速（米/秒）"),
        ("vertical", "10-500米垂直风切", "10米风与500米风差（米/秒）"),
        ("horizontal", "10米水平风速梯度", "10米风速梯度（米/秒/千米）"),
    )
    series = tuple(item for item in all_series if item[0] in selected_keys)
    # A single temperature panel needs more vertical room than the stacked
    # wind diagnostics; otherwise the long 12-hour axis makes it look flat.
    figure_height = 6.4 if len(series) == 1 else 4.8 * len(series)
    figure, axes = plt.subplots(
        len(series), 1, figsize=(16.4, figure_height), sharex=True, squeeze=False,
    )
    axes = axes[:, 0]
    palette = ("#cb3e38", "#1b64a5", "#129b78")
    legend_handles = []
    for axis, (key, title, ylabel) in zip(axes.flat, series):
        for index, (name, values) in enumerate(station_data):
            line, = axis.plot(
                x, values[key], color=palette[index], linewidth=3.6,
                marker="o", markersize=6.0, markeredgecolor="white", markeredgewidth=1.0,
                label=name,
            )
            if key == selected_keys[0]:
                legend_handles.append(line)
        axis.set_title(title, fontsize=32, loc="left", pad=14, fontweight="bold", **cn_props())
        axis.set_ylabel(ylabel, fontsize=24, labelpad=14, fontweight="bold", **cn_props())
        axis.grid(axis="y", color="#d9d9d9", linewidth=0.9)
        axis.tick_params(labelsize=20, top=True, right=True, pad=6, width=3.0, length=9)
        axis.set_xticks(x)
        axis.set_xticklabels(labels, fontsize=18, fontweight="bold", **cn_props())
    figure.legend(
        legend_handles, [airport[0] for airport in AIRPORTS],
        loc="upper center", bbox_to_anchor=(0.5, 0.985), ncol=3,
        frameon=False, fontsize=26, prop=CHINESE_FONT,
        handlelength=3.4, columnspacing=3.0, handletextpad=0.8,
    )
    figure.tight_layout(rect=(0.015, 0.02, 0.995, 0.89), h_pad=2.4)
    figure.savefig(str(output), dpi=420, bbox_inches="tight", pad_inches=0.04)
    plt.close(figure)


def montage_filename(kind, start, time_count):
    last = start + time_count - 1
    rows = max(1, int(math.ceil(time_count / 4.0)))
    return "%s_T%02d_T%02d_4x%d.png" % (kind, start, last, rows)


def write_production_manifest(output, run_id, input_path, times, start):
    """Describe production assets for build_forecast_catalog.py."""
    plot_meta = {key: (title, unit) for key, title, unit in PLOT_PRODUCTS}
    last = start + len(times) - 1
    products = []
    for product_key, title, unit, plot_keys in PRODUCTS:
        frames = []
        for plot_key in plot_keys:
            plot_title, plot_unit = plot_meta[plot_key]
            panels = []
            for lead, valid_time in enumerate(times, start):
                stamp = valid_time.astimezone(BJT).strftime("%Y%m%d_%H")
                panels.append({
                    "id": "aviation_%s_%s" % (plot_key, stamp),
                    "lead": lead,
                    "lead_label": valid_interval(valid_time),
                    "valid_label": valid_interval(valid_time),
                    "valid_time": valid_time.astimezone(BJT).isoformat(),
                    "file": "hourly_%s/%s_%s.png" % (plot_key, plot_key, stamp),
                })
            frames.append({
                "id": "aviation_%s_overview" % plot_key,
                "lead": 0,
                "lead_label": plot_title,
                "valid_label": "T%02d-T%02d" % (start, last),
                "file": montage_filename(plot_key, start, len(times)),
                "individual_frames": panels,
            })
        series_name = "airport_%s_timeseries.png" % (
            "temperature" if product_key == "temperature" else "wind"
        )
        frames.append({
            "id": "aviation_%s_series" % product_key,
            "lead": len(frames),
            "lead_label": "时间序列",
            "valid_label": "T%02d-T%02d" % (start, last),
            "file": series_name,
        })
        products.append({
            "id": "airport_aviation_%s" % product_key,
            "title": title,
            "unit": unit,
            "plot_keys": list(plot_keys),
            "frames": frames,
        })
    payload = {
        "run_id": run_id,
        "source_wrfout": str(input_path),
        "initialization_bjt": datetime.strptime(run_id, "%Y%m%d_%H").replace(
            tzinfo=timezone.utc
        ).astimezone(BJT).strftime("%Y-%m-%d %H:%M BJT"),
        "start_lead": start,
        "end_lead": last,
        "valid_times_bjt": [moment.astimezone(BJT).isoformat() for moment in times],
        "products": products,
        "airports": [airport[0] for airport in AIRPORTS],
    }
    (output / "production_manifest.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def write_web_manifest(output, times, start=13):
    """Emit the static-page manifest for this isolated, one-off preview only."""
    asset_root = (
        "https://iaplacs-forecast-images-hk.oss-cn-hongkong.aliyuncs.com/"
        "iaplacs/data/experimental/airport_aviation_20260818_00"
    )
    products = []
    for product_key, title, unit, plot_keys in PRODUCTS:
        frames = []
        for frame_index, plot_key in enumerate(plot_keys):
            plot_title, plot_unit = next(item[1:] for item in PLOT_PRODUCTS if item[0] == plot_key)
            panels = []
            for lead, valid_time in enumerate(times, 13):
                stamp = valid_time.astimezone(BJT).strftime("%Y%m%d_%H")
                relative = "hourly_%s/%s_%s" % (plot_key, plot_key, stamp)
                panels.append({
                    "id": "aviation_%s_%s" % (plot_key, stamp),
                    "lead": lead,
                    "lead_label": valid_interval(valid_time),
                    "valid_label": valid_interval(valid_time),
                    "valid_time": valid_time.astimezone(BJT).isoformat(),
                    "file": "%s/%s.webp" % (asset_root, relative),
                    "full_file": "%s/%s.png" % (asset_root, relative),
                })
            frames.append({
                "id": "aviation_%s_overview" % plot_key,
                "lead": frame_index,
                "lead_label": plot_title,
                "valid_label": "T%02d-T%02d" % (start, start + len(times) - 1),
                "file": "%s/%s" % (asset_root, montage_filename(plot_key, start, len(times)).replace(".png", ".webp")),
                "full_file": "%s/%s" % (asset_root, montage_filename(plot_key, start, len(times))),
                "individual_frames": panels,
            })
        if product_key == "temperature":
            frames.append({
                "id": "aviation_temperature_series",
                "lead": len(frames),
                "lead_label": "时间序列",
                "valid_label": "T%02d-T%02d" % (start, start + len(times) - 1),
                "file": "%s/airport_temperature_timeseries.webp" % asset_root,
                "full_file": "%s/airport_temperature_timeseries.png" % asset_root,
            })
        else:
            frames.append({
                "id": "aviation_wind_series",
                "lead": len(frames),
                "lead_label": "时间序列",
                "valid_label": "T13-T24",
                "file": "%s/airport_wind_timeseries.webp" % asset_root,
                "full_file": "%s/airport_wind_timeseries.png" % asset_root,
            })
        products.append({
            "id": "airport_aviation_%s" % product_key,
            "title": title,
            "category": "机场航空气象试验",
            "unit": unit,
            "color": "#166ab6" if product_key == "temperature" else "#168f7a",
            "description": "",
            "metrics": [
                {"label": "起报时次", "value": "20260818 00 UTC"},
                {"label": "有效时段", "value": "08-18 21时 至 08-19 08时 BJT"},
                {"label": "图像数量", "value": "12"},
            ],
            "frames": frames,
        })
    catalog = {
        "schema_version": 1,
        "site": {"name": "IAP-LACS Forecast", "domain": "iaplacs.xyz"},
        "published_at": datetime.now(BJT).isoformat(timespec="seconds"),
        "services": {"airport": {
            "title": "云南机场航空气象试验预览",
            "note": "",
            "latest_run": "airport_aviation_preview_20260818_00",
            "runs": [{
                "id": "airport_aviation_preview_20260818_00",
                "label": "2026-08-18 08:00 BJT",
                "run_time": "2026-08-18T08:00:00+08:00",
                "published_at": datetime.now(BJT).isoformat(timespec="seconds"),
                "summary": "",
                "products": products,
            }],
        }},
    }
    (output / "web_manifest.json").write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def main():
    args = arguments()
    configure_matplotlib()
    if not args.input.is_file():
        raise SystemExit("WRF file not found: %s" % args.input)
    output = args.output
    hourly_dirs = {key: output / ("hourly_" + key) for key, _, _ in PLOT_PRODUCTS}
    for directory in hourly_dirs.values():
        directory.mkdir(parents=True, exist_ok=True)
    province = shp_lines(args.province_shp)
    cities = shp_lines(args.city_shp)
    time_steps = []
    initialization_label = datetime.strptime(args.run_id, "%Y%m%d_%H").replace(
        tzinfo=timezone.utc
    ).astimezone(BJT).strftime("%Y-%m-%d %H:%M BJT")
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
            label = valid_interval(valid_time)
            stamp = valid_time.astimezone(BJT).strftime("%Y%m%d_%H")
            for key, title, unit in PLOT_PRODUCTS:
                panel = hourly_dirs[key] / ("%s_%s.png" % (key, stamp))
                single_map(panel, crop_lon, crop_lat, data, key, title, unit, label, province, cities)
            time_steps.append((data, valid_time))
            for station, (y, x) in enumerate(station_indexes):
                station_values[station]["temperature"].append(float(data[0][y - row0, x - col0]))
                station_values[station]["wind"].append(float(math.hypot(data[1][y - row0, x - col0], data[2][y - row0, x - col0])))
                station_values[station]["vertical"].append(float(data[3][y - row0, x - col0]))
                station_values[station]["horizontal"].append(float(data[4][y - row0, x - col0]))
    for key, title, unit in PLOT_PRODUCTS:
        montage(
            time_steps,
            output / montage_filename(key, args.start, len(times)),
            crop_lon,
            crop_lat,
            key,
            title,
            unit,
            province,
            cities,
            initialization_label,
        )
    station_data = [(airport[0], station_values[index]) for index, airport in enumerate(AIRPORTS)]
    station_meteogram(
        output / "airport_temperature_timeseries.png",
        [moment.astimezone(BJT) for moment in times], station_data, ("temperature",),
    )
    station_meteogram(
        output / "airport_wind_timeseries.png",
        [moment.astimezone(BJT) for moment in times], station_data,
        ("wind", "vertical", "horizontal"),
    )
    manifest = {
        "experimental": not args.production,
        "publishable": args.production,
        "source_wrfout": str(args.input),
        "initialization_bjt": initialization_label,
        "lead_indices": "T%d–T%d" % (args.start, args.start + len(times) - 1),
        "valid_times_bjt": [moment.astimezone(BJT).isoformat() for moment in times],
        "products": [title for _, title, _, _ in PRODUCTS],
        "airports": [airport[0] for airport in AIRPORTS],
    }
    (output / ("production_manifest.json" if args.production else "preview_manifest.json")).write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    if args.production:
        write_production_manifest(output, args.run_id, args.input, times, args.start)
    else:
        write_web_manifest(output, [moment.astimezone(BJT) for moment in times], args.start)
    print("wrote preview to %s" % output)


if __name__ == "__main__":
    main()
