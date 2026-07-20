#!/usr/bin/env python3
"""Extract T13-T48 point precipitation totals for Yunnan airport products."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from netCDF4 import Dataset


AIRPORTS = [
    {
        "id": "dehong_mangshi",
        "name": "德宏芒市国际机场",
        "lat": 24.400000,
        "lon": 98.533333,
    },
    {
        "id": "xishuangbanna_gasa",
        "name": "西双版纳嘎洒国际机场",
        "lat": 21.975000,
        "lon": 100.761667,
    },
    {
        "id": "puer_lancang_jingmai",
        "name": "普洱澜沧景迈机场",
        "lat": 22.416944,
        "lon": 99.784444,
    },
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--wrf-dir", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--start", default=13, type=int)
    parser.add_argument("--end", default=48, type=int)
    parser.add_argument("--max-distance-deg", default=0.35, type=float)
    return parser.parse_args()


def nearest_grid(
    lat2d: np.ndarray, lon2d: np.ndarray, lat: float, lon: float
) -> tuple[int, int, float]:
    distance = (lat2d - lat) ** 2 + (lon2d - lon) ** 2
    y, x = np.unravel_index(np.nanargmin(distance), distance.shape)
    return int(y), int(x), float(np.sqrt(distance[y, x]))


def read_times(ds: Dataset) -> list[str]:
    times = ds.variables.get("Times")
    if times is None:
        return []
    return ["".join(chars.astype(str)).strip() for chars in times[:]]


def extract_file(path: Path, start: int, end: int, max_distance_deg: float) -> dict:
    with Dataset(path) as ds:
        time_count = len(ds.dimensions["Time"])
        if time_count <= start:
            raise ValueError(f"{path} has only {time_count} time steps")
        end_idx = min(end, time_count - 1)

        lat2d = ds.variables["XLAT"][0, :, :]
        lon2d = ds.variables["XLONG"][0, :, :]
        times = read_times(ds)

        results = []
        for airport in AIRPORTS:
            y, x, distance_deg = nearest_grid(
                lat2d, lon2d, airport["lat"], airport["lon"]
            )
            point = {
                **airport,
                "nearest_lat": round(float(lat2d[y, x]), 6),
                "nearest_lon": round(float(lon2d[y, x]), 6),
                "nearest_distance_deg": round(distance_deg, 3),
                "grid_y": y,
                "grid_x": x,
            }
            if distance_deg > max_distance_deg:
                results.append(
                    {
                        **point,
                        "status": "outside_domain",
                        "total_mm": None,
                        "max_hourly_mm": None,
                        "note": "机场点超出当前 WORK_nx d01 网格覆盖范围",
                    }
                )
                continue

            accum = (
                ds.variables["RAINNC"][:, y, x].astype("float64")
                + ds.variables["RAINC"][:, y, x].astype("float64")
            )
            hourly = accum[start : end_idx + 1] - accum[start - 1 : end_idx]
            hourly = np.maximum(hourly, 0.0)
            results.append(
                {
                    **point,
                    "status": "ok",
                    "total_mm": round(float(np.sum(hourly)), 1),
                    "max_hourly_mm": round(float(np.max(hourly)), 1),
                }
            )

        return {
            "source_wrfout": str(path),
            "lead_start": start,
            "lead_end": end_idx,
            "unit": "mm",
            "valid_time_start": times[start - 1] if len(times) > start - 1 else "",
            "valid_time_end": times[end_idx] if len(times) > end_idx else "",
            "airports": results,
        }


def main() -> None:
    args = parse_args()
    wrf_files = sorted(args.wrf_dir.glob("wrfout_d01_*"))
    if not wrf_files:
        raise SystemExit(f"no wrfout_d01_* files in {args.wrf_dir}")

    payload = extract_file(wrf_files[0], args.start, args.end, args.max_distance_deg)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {args.output}")


if __name__ == "__main__":
    main()
