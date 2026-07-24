#!/usr/bin/env python3
"""Create bounded WebP forecast assets on Tianhe with the existing Pillow."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--maps-dir", type=Path, required=True)
    parser.add_argument("--max-size", type=int, default=3200)
    parser.add_argument("--preview-size", type=int, default=1200)
    parser.add_argument("--quality", type=int, default=82)
    return parser.parse_args()


def webp_target(source: Path, preview: bool = False) -> Path:
    suffix = ".preview.webp" if preview else ".webp"
    return source.with_suffix("").with_suffix(suffix)


def needs_refresh(source: Path, target: Path) -> bool:
    return not target.exists() or target.stat().st_mtime < source.stat().st_mtime


def save_webp(source: Path, target: Path, max_size: int, quality: int) -> None:
    with Image.open(source) as image:
        image.load()
        image.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
        if image.mode not in {"RGB", "RGBA"}:
            image = image.convert("RGBA" if "transparency" in image.info else "RGB")
        target.parent.mkdir(parents=True, exist_ok=True)
        image.save(target, "WEBP", quality=quality, method=6)
    stat = source.stat()
    os.utime(target, (stat.st_atime, stat.st_mtime))


def main() -> int:
    args = parse_args()
    maps_dir = args.maps_dir.resolve()
    if not maps_dir.is_dir():
        raise SystemExit(f"maps directory does not exist: {maps_dir}")
    if args.max_size < 1 or args.preview_size < 1:
        raise SystemExit("image sizes must be positive")

    converted = 0
    for source in sorted(maps_dir.rglob("*")):
        if not source.is_file() or source.suffix.lower() not in {".png", ".jpg", ".jpeg"}:
            continue
        for target, size, quality in (
            (webp_target(source), args.max_size, args.quality),
            (webp_target(source, preview=True), args.preview_size, 76),
        ):
            if not needs_refresh(source, target):
                continue
            save_webp(source, target, size, quality)
            converted += 1
            print(f"webp: {target.relative_to(maps_dir)}")
    print(f"converted={converted}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
