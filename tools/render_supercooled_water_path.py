#!/usr/bin/env python3
"""Prepare paired regional/d01 water paths; no network or catalog writes."""

from __future__ import annotations

import argparse
import hashlib
import json
import logging
import math
import shutil
import time
from datetime import datetime, timezone
from pathlib import Path

from plot_runtime import require_plot_allocation

if __name__ == "__main__":
    require_plot_allocation()

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.axes import Axes
from matplotlib.collections import QuadMesh
from matplotlib.colors import BoundaryNorm, ListedColormap
from matplotlib.figure import Figure
from netCDF4 import Dataset
from render_work_visibility import map_ticks, select_indices
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
from supercooled_contract import PROFILES, TITLES, choose_sources, validate_manifest
from supercooled_wrf_io import LEVELS, atomic_json, extract

LOG = logging.getLogger(__name__)
COLORS = [
    "#e3f4fb",
    "#b5e0ef",
    "#75bcd8",
    "#3286bd",
    "#40ad91",
    "#a3cb64",
    "#f5df69",
    "#f69a46",
    "#d44835",
]
CODE_FILES = (
    "render_supercooled_water_path.py",
    "supercooled_water_path.py",
    "supercooled_wrf_io.py",
    "supercooled_contract.py",
    "render_yunnan_airport_aviation_preview.py",
    "render_work_visibility.py",
)


def stamp(path: Path) -> dict:
    stat = path.stat()
    return {
        "path": str(path.resolve()),
        "size": stat.st_size,
        "mtime_ns": stat.st_mtime_ns,
    }


def signature(args: argparse.Namespace, sources: dict[str, Path]) -> dict:
    files = [Path(__file__).with_name(name) for name in CODE_FILES]
    files.extend(args.province_shp.with_suffix(s) for s in (".shp", ".shx", ".dbf"))
    if args.city_shp:
        files.extend(args.city_shp.with_suffix(s) for s in (".shp", ".shx", ".dbf"))
    return {
        "inputs": {area: stamp(path) for area, path in sources.items()},
        "code_and_shapes": {
            str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in files
        },
        "profile": args.profile,
        "run": args.run,
        "count": args.count,
        "start_hour": 13,
        "dpi": 400,
        "levels_g_m2": LEVELS,
    }


def selected_times(
    source: Path, count: int
) -> tuple[datetime, list[int], list[datetime]]:
    with Dataset(source) as ds:
        times = wrf_times(ds)
    indices = select_indices(times, 13, count)
    return times[0], indices, [times[i] for i in indices]


def geographic_extent(
    profile: str, area: str, domain: str, lat: np.ndarray, lon: np.ndarray
) -> tuple:
    if area == "wide":
        return (
            math.floor(float(lon.min())),
            min(145.0, math.ceil(float(lon.max()))),
            math.floor(float(lat.min())),
            math.ceil(float(lat.max())),
        )
    if profile == "ningxia":
        return (104.0, 107.8, 35.0, 39.7)
    return display_region(
        lat,
        lon,
        domain,
        REGION_PROFILES[profile]["default_region"],
        west_margin=0.5 if profile == "xinjiang" else 0.1,
    )


def draw_panel(
    ax: Axes,
    record: dict,
    kind: str,
    extent: tuple,
    province: list,
    cities: list,
    airports: tuple,
    *,
    montage: bool = False,
) -> QuadMesh:
    palette = ListedColormap(COLORS)
    palette.set_under("white")
    palette.set_bad("white")
    palette.set_over("#8d2036")
    artist = ax.pcolormesh(
        record["lon"],
        record["lat"],
        np.ma.masked_invalid(record[kind]),
        cmap=palette,
        norm=BoundaryNorm(LEVELS, palette.N),
        shading="nearest",
        rasterized=True,
    )
    size = 16 if montage else 18
    decorate(ax, province, cities, extent, airports, tick_size=size, plane_scale=0.12)
    for name, low, high, suffix in (
        ("x", extent[0], extent[1], "E"),
        ("y", extent[2], extent[3], "N"),
    ):
        ticks = map_ticks(low, high)
        if record["profile"] == "xinjiang" and record["area"] == "regional":
            origin, step = (72, 8) if name == "x" else (34, 4)
            ticks = np.arange(
                origin + math.ceil((low - origin) / step) * step, high + 0.001, step
            )
        getattr(ax, f"set_{name}ticks")(ticks)
        getattr(ax, f"set_{name}ticklabels")(
            [f"{v:g}°{suffix}" for v in ticks], fontsize=size, fontweight="bold"
        )
    labels = ax.get_xticklabels()
    if labels:
        if abs(ax.get_xticks()[0] - extent[0]) < 0.1:
            labels[0].set_ha("left")
        if abs(ax.get_xticks()[-1] - extent[1]) < 0.1:
            labels[-1].set_ha("right")
    ax.tick_params(width=3, length=8, pad=3)
    ax.set_title(record["label"], fontsize=18 if montage else 22, pad=6)
    return artist


def save_maps(
    output: Path,
    records: list[dict],
    kind: str,
    area: str,
    label: str,
    extent: tuple,
    province: list,
    cities: list,
    airports: tuple,
    initial: datetime,
) -> dict:
    panels = []
    ratio = (extent[1] - extent[0]) / (extent[3] - extent[2])
    for index, record in enumerate(records):
        name = f"{area}/{kind}_{index:03d}.png"
        (output / area).mkdir(exist_ok=True)
        fig, ax = plt.subplots(figsize=(12, max(5, 10 / ratio + 0.8)))
        fig.subplots_adjust(left=0.09, right=0.84, bottom=0.1, top=0.9)
        artist = draw_panel(ax, record, kind, extent, province, cities, airports)
        cax = fig.add_axes([0.88, 0.15, 0.025, 0.7])
        add_colorbar(fig, artist, cax)
        fig.savefig(output / name, dpi=400, bbox_inches="tight", pad_inches=0.08)
        plt.close(fig)
        panels.append(
            {
                "id": f"{kind}_{area}_{index:03d}",
                "file": name,
                "valid_time": record["valid_time"],
                "time_kind": "instant",
                "lead_label": record["label"],
                "valid_label": record["label"],
            }
        )
    cols = 3 if len(records) == 12 else min(4, len(records))
    rows = math.ceil(len(records) / cols)
    height = 5.0 / ratio + 0.65
    fig, axes = plt.subplots(
        rows, cols, figsize=(cols * 5.7 + 1.1, rows * height + 1), squeeze=False
    )
    fig.subplots_adjust(
        left=0.045, right=0.915, bottom=0.04, top=0.93, wspace=0.2, hspace=0.27
    )
    for index, ax in enumerate(axes.flat):
        if index >= len(records):
            ax.set_visible(False)
            continue
        artist = draw_panel(
            ax, records[index], kind, extent, province, cities, airports, montage=True
        )
    fig.suptitle(
        initial.astimezone(BJT).strftime("Forecast Initialization: %Y-%m-%d %H:%M BJT"),
        fontsize=24,
        weight="bold",
        y=0.98,
    )
    cax = fig.add_axes([0.945, 0.15, 0.016, 0.65])
    add_colorbar(fig, artist, cax)
    name = f"{area}/{kind}_montage.png"
    fig.savefig(output / name, dpi=400, bbox_inches="tight", pad_inches=0.08)
    plt.close(fig)
    return {
        "id": area,
        "lead": 0 if area == "regional" else 1,
        "lead_label": label,
        "valid_label": label,
        "file": name,
        "individual_frames": panels,
    }


def add_colorbar(figure: Figure, artist: QuadMesh, axis: Axes) -> None:
    bar = figure.colorbar(
        artist, cax=axis, ticks=LEVELS, extend="max", spacing="uniform"
    )
    bar.ax.tick_params(labelsize=16, width=2, length=5)
    bar.set_label("g m$^{-2}$", fontsize=20, weight="bold")
    bar.outline.set_linewidth(2.5)


def collect_source_records(
    source: Path, areas: list[str], indices: list[int], profile: str
) -> tuple[dict, dict, list]:
    """Integrate each time once; retain only cropped 2-D arrays for each area."""
    records = {area: [] for area in areas}
    extents = {}
    diagnostics = []
    domain = "d02" if source.name.startswith("wrfout_d02_") else "d01"
    for index in indices:
        lon, lat, fields, info = extract(source, index)
        for area in areas:
            extent = geographic_extent(profile, area, domain, lat, lon)
            extents[area] = extent
            y0, y1, x0, x1 = crop_indices(lat, lon, extent)
            region = np.s_[y0 : y1 + 1, x0 : x1 + 1]
            if any(not np.isfinite(fields[kind][region]).any() for kind in TITLES):
                raise ValueError(
                    f"No valid {area} water-path columns at {info['valid_utc']}"
                )
            records[area].append(
                {
                    "profile": profile,
                    "area": area,
                    # Copies avoid keeping full-domain arrays alive via small views.
                    "lat": lat[region].copy(),
                    "lon": lon[region].copy(),
                    "cloud": fields["cloud"][region].copy(),
                    "rain": fields["rain"][region].copy(),
                    "valid_time": info["valid_utc"],
                    "label": datetime.fromisoformat(info["valid_utc"])
                    .astimezone(BJT)
                    .strftime("%m-%d %H:%M BJT"),
                }
            )
            diagnostics.append({"area": area, "domain": domain, **info})
    return records, extents, diagnostics


def render(args: argparse.Namespace) -> dict:
    sources = choose_sources(args.input)
    fingerprint = signature(args, sources)
    initial, _, reference = selected_times(sources["wide"], args.count)
    expected_init = datetime.strptime(args.run, "%Y%m%d_%H").replace(
        tzinfo=timezone.utc
    )
    if initial != expected_init:
        raise ValueError("Requested run differs from WRF initialization")
    selections = {}
    for area, path in sources.items():
        start, indices, times = selected_times(path, args.count)
        if start != initial or times != reference:
            raise ValueError(
                "d01/d02 initialization or selected times differ; retry when complete"
            )
        selections[area] = indices
    key = hashlib.sha256(json.dumps(fingerprint, sort_keys=True).encode()).hexdigest()[
        :20
    ]
    manifest_path = args.output / "production_manifest.json"
    if manifest_path.exists():
        old = json.loads(manifest_path.read_text(encoding="utf-8"))
        if old.get("source_signature") == fingerprint:
            try:
                validate_manifest(old, args.output, require_ready=False)
                return old
            except (ValueError, KeyError):
                LOG.warning("Incomplete cached bundle; rebuilding")
    args.output.mkdir(parents=True, exist_ok=True)
    stage = args.output / f".building-{key}"
    if stage.exists():
        shutil.rmtree(stage)
    stage.mkdir()
    configure_matplotlib()
    plt.rcParams.update(
        {
            "figure.facecolor": "white",
            "axes.facecolor": "white",
            "pdf.fonttype": 42,
            "ps.fonttype": 42,
        }
    )
    province = shp_lines(args.province_shp)
    cities = shp_lines(args.city_shp) if args.city_shp else []
    airports = REGION_PROFILES.get(args.profile, {}).get("airports", ())
    profile = PROFILES[args.profile]
    frames = {kind: [] for kind in TITLES}
    diagnostics = []
    grouped_sources = {}
    for area, source in sources.items():
        grouped_sources.setdefault(source.resolve(), []).append(area)
    for source, areas in grouped_sources.items():
        started = time.monotonic()
        records, extents, info = collect_source_records(
            source, areas, selections[areas[0]], args.profile
        )
        diagnostics.extend(info)
        LOG.info("Integration areas=%s seconds=%.1f", areas, time.monotonic() - started)
        started = time.monotonic()
        for area in areas:
            for kind in TITLES:
                frames[kind].append(
                    save_maps(
                        stage,
                        records[area],
                        kind,
                        area,
                        profile["region" if area == "regional" else "wide"],
                        extents[area],
                        province,
                        cities if area == "regional" else [],
                        airports,
                        initial,
                    )
                )
        LOG.info("Drawing areas=%s seconds=%.1f", areas, time.monotonic() - started)
        del records
    if signature(args, choose_sources(args.input)) != fingerprint:
        raise RuntimeError("Input or rendering dependencies changed; refusing bundle")
    atomic_json(stage / "diagnostics.json", {"records": diagnostics})
    products = [
        {
            "id": f"{profile['prefix']}_supercooled_{kind}",
            "title": title,
            "unit": "g/m²",
            "color": "#0f68c8",
            "description": "",
            "frames": frames[kind],
        }
        for kind, title in TITLES.items()
    ]
    # Immutable generation paths prevent an old catalog reading half-replaced images.
    generation = args.output / key
    if generation.exists():
        shutil.rmtree(generation)
    stage.rename(generation)
    for product in products:
        for frame in product["frames"]:
            for image in [frame, *frame["individual_frames"]]:
                image["file"] = f"{key}/{image['file']}"
    manifest = {
        "schema_version": 1,
        "profile": args.profile,
        "run": args.run,
        "generated_at": datetime.now(BJT).isoformat(),
        "publication_ready": args.count == 1000,
        "source_signature": fingerprint,
        "generation": key,
        "method": "sum(rho_d*q*dz) for T<273.15K; instantaneous resolved liquid",
        "colorbar_status": "experimental display bins; not icing severity",
        "products": products,
    }
    validate_manifest(manifest, args.output, require_ready=False)
    atomic_json(manifest_path, manifest)
    return manifest


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--input",
        required=True,
        type=Path,
        help="Same-run d01; d02 selected automatically",
    )
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--run", required=True)
    parser.add_argument("--profile", required=True, choices=PROFILES)
    parser.add_argument("--province-shp", required=True, type=Path)
    parser.add_argument("--city-shp", type=Path)
    parser.add_argument(
        "--count",
        type=int,
        default=1000,
        help="Preview limit; non-default bundles cannot publish",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    logging.basicConfig(level=logging.INFO)
    render(args)
    LOG.info("Prepared %s %s at %s", args.profile, args.run, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
