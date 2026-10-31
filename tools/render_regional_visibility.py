#!/usr/bin/env python3
"""Publish nested regional and full outer-domain visibility as separate views."""

import copy
import hashlib
import json
import logging
from pathlib import Path

from render_cloud_visibility_preview import main as render_cloud
from render_work_visibility import atomic_json, build_parser, is_current
from visibility_source import select_source

LOG = logging.getLogger(__name__)


def prefix_frame(frame: dict, prefix: str) -> dict:
    result = copy.deepcopy(frame)
    result["file"] = prefix + "/" + result["file"]
    result["individual_frames"] = [
        {**child, "file": prefix + "/" + child["file"]}
        for child in result.get("individual_frames", [])
    ]
    return result


def retire_flat_assets(output: Path, previous: dict) -> None:
    """Remove only obsolete top-level images owned by the old single-view manifest."""
    for product in previous.get("products", []):
        for frame in product.get("frames", []):
            for asset in [frame] + frame.get("individual_frames", []):
                name = Path(asset["file"])
                if name.name != str(name) or name.suffix != ".png":
                    continue
                for suffix in (".png", ".webp"):
                    (output / name.with_suffix(suffix)).unlink(missing_ok=True)


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.profile not in {"yunnan", "xinjiang"}:
        raise ValueError("Dual-domain visibility supports Yunnan/Xinjiang only")
    logging.basicConfig(level=logging.INFO)
    d01 = args.input.with_name(args.input.name.replace("d02", "d01", 1))
    manifest_path = args.output / "production_manifest.json"
    previous = (
        json.loads(manifest_path.read_text(encoding="utf-8"))
        if manifest_path.is_file()
        else {}
    )
    manifests = {}
    for area, prefer_nested in [("regional", True), ("wide", False)]:
        selected = select_source(d01, args.profile, prefer_nested=prefer_nested)
        if selected is None:
            LOG.warning("No supported visibility input for %s", area)
            continue
        source, _ = selected
        domain = "d02" if "wrfout_d02_" in source.name else "d01"
        output = args.output / area
        command = [
            "--input",
            str(source),
            "--output",
            str(output),
            "--profile",
            args.profile,
            "--domain",
            domain,
            "--area",
            area,
            "--variable",
            "auto",
            "--production",
            "--if-needed",
            "--province-shp",
            str(args.province_shp),
            "--start",
            str(args.start),
            "--count",
            str(args.count),
            "--dpi",
            str(args.dpi),
        ]
        if args.county_shp and area == "regional":
            command.extend(["--county-shp", str(args.county_shp)])
        status = render_cloud(command)
        if status:
            return status
        manifests[area] = json.loads(
            (output / "production_manifest.json").read_text(encoding="utf-8")
        )
    if not manifests:
        return 3
    signature = {
        "orchestrator_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "areas": {area: m["source_signature"] for area, m in manifests.items()},
    }
    if is_current(args.output, signature):
        LOG.info("Both visibility views are current")
        return 0
    first = next(iter(manifests.values()))
    product = copy.deepcopy(first["products"][0])
    product["description"] = ""
    units = {m["products"][0]["unit"] for m in manifests.values()}
    if len(units) > 1:
        product["unit"] = "最低模式层能见度（米；来源见各区域）"
    product["frames"] = []
    for index, (area, manifest) in enumerate(manifests.items()):
        frame = prefix_frame(manifest["products"][0]["frames"][0], area)
        frame["lead"] = index
        frame["source_variable"] = manifest["source_variable"]
        product["frames"].append(frame)
    combined = {
        "source_signature": signature,
        "run_time": first["run_time"],
        "generated_at": max(m["generated_at"] for m in manifests.values()),
        "source_variables": {
            area: m["source_variable"] for area, m in manifests.items()
        },
        "preview_only": False,
        "products": [product],
    }
    atomic_json(manifest_path, combined)
    retire_flat_assets(args.output, previous)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
