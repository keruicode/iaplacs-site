"""Dependency-free contract shared by rendering, catalog and publication checks."""

from __future__ import annotations

from pathlib import Path

PROFILES = {
    "ningxia": {
        "prefix": "ningxia",
        "model": "WORK",
        "region": "宁夏区域",
        "wide": "中国中东部",
        "family": "worknx_summary",
    },
    "yunnan": {
        "prefix": "airport",
        "model": "WORK_yn",
        "region": "云南区域",
        "wide": "中国西南部",
        "family": "airport_yunnan",
    },
    "xinjiang": {
        "prefix": "xinjiang",
        "model": "WORK_xj",
        "region": "新疆区域",
        "wide": "中国西北部",
        "family": "workxj_summary",
    },
}
TITLES = {"cloud": "过冷云水路径", "rain": "过冷雨水路径"}


def choose_sources(d01: Path) -> dict[str, Path]:
    """Never substitute another run or silently discard a present nested file."""
    if not d01.name.startswith("wrfout_d01_") or not d01.is_file():
        raise ValueError(f"Expected existing d01 file: {d01}")
    d02 = d01.with_name(d01.name.replace("wrfout_d01_", "wrfout_d02_", 1))
    return {"regional": d02 if d02.exists() else d01, "wide": d01}


def validate_manifest(
    manifest: dict, root: Path, *, require_ready: bool = True
) -> None:
    """Reject partial pairs, unsafe paths and missing images before publication."""
    profile = PROFILES[manifest["profile"]]
    if require_ready and manifest.get("publication_ready") is not True:
        raise ValueError("Preview or incomplete bundle cannot be published")
    products = manifest.get("products", [])
    expected = {f"{profile['prefix']}_supercooled_{kind}" for kind in TITLES}
    if len(products) != 2 or {p.get("id") for p in products} != expected:
        raise ValueError("Both supercooled cloud and rain products are required")
    reference_times = None
    for product in products:
        if product.get("unit") != "g/m²":
            raise ValueError("Water path unit must be g/m2")
        frames = product.get("frames", [])
        if [f.get("id") for f in frames] != ["regional", "wide"]:
            raise ValueError("Regional and d01 wide frames must both be present")
        for frame in frames:
            panels = frame.get("individual_frames", [])
            times = [p.get("valid_time") for p in panels]
            if not times or any(not t for t in times) or times != sorted(set(times)):
                raise ValueError("Hourly times must be nonempty, unique and increasing")
            if reference_times is not None and times != reference_times:
                raise ValueError("All four product/area combinations must share times")
            reference_times = times
            for image in [frame, *panels]:
                path = (root / image["file"]).resolve()
                if not path.is_relative_to(root.resolve()):
                    raise ValueError("Image path escapes the bundle")
                if not path.is_file() or path.stat().st_size == 0:
                    raise ValueError(f"Missing image: {path}")
