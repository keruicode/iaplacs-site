#!/usr/bin/env python3
"""Attach published hourly precipitation panels to an existing catalog run."""

from __future__ import annotations

import argparse
import json
import os
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path


BJT = timezone(timedelta(hours=8))
DEFAULT_ASSET_BASE_URL = (
    "https://iaplacs-forecast-images-hk.oss-cn-hongkong.aliyuncs.com/iaplacs"
)
PANEL_RE = re.compile(
    r"^(?P<run>\d{8}_\d{2})_"
    r"(?P<area>ningxia_region|worknx_national|shangrao_region|shangrao_national|xinjiang_region|workxj_national)_"
    r"rain_hour_(?P<start>\d{10})-(?P<end>\d{10})_BJT\.webp$",
    re.IGNORECASE,
)
FAMILY_CONFIG = {
    "worknx_summary": {
        "service": "ningxia",
        "products": {"ningxia_precip_series"},
        "frames": {"ningxia_region", "worknx_national"},
    },
    "wrf_montage": {
        "service": "shangrao",
        "products": {"wrf_rain_montage"},
        "frames": {"shangrao_region", "shangrao_national"},
    },
    "workxj_summary": {
        "service": "xinjiang",
        "products": {"xinjiang_precip_series"},
        "frames": {"xinjiang_region", "workxj_national"},
    },
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--asset-dir", type=Path, required=True)
    parser.add_argument("--family", choices=sorted(FAMILY_CONFIG), required=True)
    parser.add_argument("--run-prefix", required=True)
    args = parser.parse_args()

    if not re.fullmatch(r"\d{8}_\d{2}", args.run_prefix):
        parser.error("--run-prefix must use YYYYMMDD_HH")
    if not args.catalog.is_file():
        parser.error(f"catalog does not exist: {args.catalog}")
    if not args.asset_dir.is_dir():
        parser.error(f"asset directory does not exist: {args.asset_dir}")

    config = FAMILY_CONFIG[args.family]
    panels = scan_panels(args.asset_dir, args.run_prefix, config["frames"])
    missing = sorted(frame_id for frame_id in config["frames"] if not panels[frame_id])
    if missing:
        parser.error(f"missing hourly panels for: {', '.join(missing)}")
    validate_panel_sequences(args.family, args.run_prefix, panels)

    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    service = catalog.get("services", {}).get(config["service"], {})
    run = next((item for item in service.get("runs", []) if item.get("id") == args.run_prefix), None)
    if run is None:
        parser.error(f"run {args.run_prefix} not found in {config['service']} service")

    product = next(
        (item for item in run.get("products", []) if item.get("id") in config["products"]),
        None,
    )
    if product is None:
        parser.error(f"hourly precipitation product not found for {args.run_prefix}")

    updated = set()
    for frame in product.get("frames", []):
        frame_id = frame.get("id")
        if frame_id in panels:
            frame["individual_frames"] = panels[frame_id]
            updated.add(frame_id)
    if updated != config["frames"]:
        parser.error(f"catalog frames missing: {', '.join(sorted(config['frames'] - updated))}")

    args.catalog.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    counts = ", ".join(f"{frame_id}={len(panels[frame_id])}" for frame_id in sorted(updated))
    print(f"attached hourly panels to {config['service']} {args.run_prefix}: {counts}")


def scan_panels(
    asset_dir: Path, run_prefix: str, frame_ids: set[str]
) -> dict[str, list[dict]]:
    asset_base_url = os.environ.get(
        "IAPLACS_ASSET_BASE_URL", DEFAULT_ASSET_BASE_URL
    ).strip().rstrip("/")
    root = asset_dir.parents[3]
    grouped: dict[str, list[tuple[datetime, dict]]] = {
        frame_id: [] for frame_id in frame_ids
    }
    for path in sorted(asset_dir.glob(f"{run_prefix}_*_rain_hour_*_BJT.webp")):
        match = PANEL_RE.match(path.name)
        if not match or match.group("run") != run_prefix:
            continue
        frame_id = match.group("area").lower()
        if frame_id not in frame_ids:
            continue
        start = datetime.strptime(match.group("start"), "%Y%m%d%H").replace(tzinfo=BJT)
        end = datetime.strptime(match.group("end"), "%Y%m%d%H").replace(tzinfo=BJT)
        relative = path.relative_to(root).as_posix()
        file_url = f"{asset_base_url}/{relative}" if asset_base_url else f"./{relative}"
        grouped[frame_id].append(
            (
                start,
                {
                    "id": f"{frame_id}_hour_{start:%Y%m%d%H}",
                    "lead_label": f"{start:%m-%d %H:00}-{end:%H:00}",
                    "valid_label": f"{start:%Y-%m-%d %H:00}-{end:%H:00} BJT",
                    "valid_time": end.astimezone(timezone.utc)
                    .isoformat()
                    .replace("+00:00", "Z"),
                    "file": file_url,
                    "bytes": path.stat().st_size,
                },
            )
        )

    normalized: dict[str, list[dict]] = {}
    for frame_id, candidates in grouped.items():
        ordered = [frame for _, frame in sorted(candidates, key=lambda item: item[0])]
        for lead, frame in enumerate(ordered, start=1):
            frame["lead"] = lead
        normalized[frame_id] = ordered
    return normalized


def validate_panel_sequences(
    family: str, run_prefix: str, panels: dict[str, list[dict]]
) -> None:
    init = datetime.strptime(run_prefix, "%Y%m%d_%H").replace(tzinfo=BJT)
    if family in {"worknx_summary", "workxj_summary"}:
        # WORK_nx run prefixes are UTC; convert to BJT before adding spin-up.
        init += timedelta(hours=8)
    expected_start = init + timedelta(hours=12)

    starts_by_frame: dict[str, list[datetime]] = {}
    for frame_id, frames in panels.items():
        starts = [
            datetime.strptime(frame["id"].rsplit("_", 1)[-1], "%Y%m%d%H").replace(tzinfo=BJT)
            for frame in frames
        ]
        if starts[0] != expected_start:
            raise SystemExit(
                f"ERROR: {frame_id} starts at {starts[0]:%Y-%m-%d %H:%M} BJT; "
                f"expected {expected_start:%Y-%m-%d %H:%M} BJT"
            )
        for previous, current in zip(starts, starts[1:]):
            if current - previous != timedelta(hours=1):
                raise SystemExit(f"ERROR: {frame_id} hourly sequence is discontinuous")
        starts_by_frame[frame_id] = starts

    sequences = list(starts_by_frame.values())
    if any(sequence != sequences[0] for sequence in sequences[1:]):
        raise SystemExit("ERROR: regional and national hourly sequences differ")


if __name__ == "__main__":
    main()
