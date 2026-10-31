#!/usr/bin/env python3
"""Require a diagnostic product in the catalog before recording upload success."""

import argparse
import json
import logging
from pathlib import Path

LOG = logging.getLogger(__name__)


def verify_catalog(catalog: dict, manifest: dict, family: str, run: str) -> None:
    service, prefix = {
        "airport_yunnan": ("airport", "airport_yunnan_"),
        "workxj_summary": ("xinjiang", ""),
        "worknx_summary": ("ningxia", ""),
    }[family]
    runs = catalog["services"][service]["runs"]
    selected = next((r for r in runs if r["id"] == prefix + run), None)
    if selected is None:
        raise ValueError("Base forecast run is not yet in the catalog")
    products = {p["id"]: p for p in selected["products"]}
    for expected in manifest["products"]:
        actual = products.get(expected["id"])
        if actual is None or actual.get("unit") != expected.get("unit"):
            raise ValueError("Diagnostic product or variable label is missing/stale")
        frames = actual.get("frames", [])
        if len(frames) != len(expected["frames"]):
            raise ValueError("Diagnostic area count differs")
        for a, e in zip(frames, expected["frames"]):
            if len(a.get("individual_frames", [])) != len(
                e.get("individual_frames", [])
            ):
                raise ValueError("Diagnostic hourly frame count differs")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--family", required=True)
    parser.add_argument("--run", required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        verify_catalog(
            json.loads(args.catalog.read_text(encoding="utf-8")),
            json.loads(args.manifest.read_text(encoding="utf-8")),
            args.family,
            args.run,
        )
    except ValueError as error:
        LOG.warning("Publication deferred; retry next audit: %s", error)
        return 75
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
