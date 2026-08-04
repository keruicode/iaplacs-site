#!/usr/bin/env python3
"""Validate regional and national hourly precipitation panel sequences."""

from __future__ import annotations

import argparse
import re
from datetime import datetime, timedelta
from pathlib import Path


PANEL_RE = re.compile(r"_rain_hour_(\d{10})-(\d{10})_BJT\.png$")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-prefix", required=True)
    parser.add_argument("--run-time-basis", choices=("utc", "bjt"), required=True)
    parser.add_argument("--regional-dir", type=Path, required=True)
    parser.add_argument("--national-dir", type=Path, required=True)
    parser.add_argument("--filename-prefix", default="")
    args = parser.parse_args()

    try:
        init = datetime.strptime(args.run_prefix, "%Y%m%d_%H")
    except ValueError as exc:
        parser.error(f"invalid --run-prefix: {exc}")

    expected_first = init + timedelta(hours=12 + (8 if args.run_time_basis == "utc" else 0))
    regional = scan(args.regional_dir, args.filename_prefix)
    national = scan(args.national_dir, args.filename_prefix)
    validate("regional", regional, expected_first)
    validate("national", national, expected_first)
    if regional != national:
        raise SystemExit(
            "ERROR: regional and national hourly windows differ: "
            f"regional={format_windows(regional)} national={format_windows(national)}"
        )

    print(
        f"validated {len(regional)} hourly panels: "
        f"{format_window(regional[0])} through {format_window(regional[-1])}"
    )


def scan(directory: Path, filename_prefix: str) -> list[tuple[datetime, datetime]]:
    if not directory.is_dir():
        raise SystemExit(f"ERROR: hourly panel directory not found: {directory}")
    windows = []
    for path in sorted(directory.glob("*_rain_hour_*_BJT.png")):
        if filename_prefix and not path.name.startswith(filename_prefix):
            continue
        match = PANEL_RE.search(path.name)
        if not match:
            continue
        windows.append(
            (
                datetime.strptime(match.group(1), "%Y%m%d%H"),
                datetime.strptime(match.group(2), "%Y%m%d%H"),
            )
        )
    return sorted(set(windows))


def validate(
    label: str,
    windows: list[tuple[datetime, datetime]],
    expected_first: datetime,
) -> None:
    if not windows:
        raise SystemExit(f"ERROR: no {label} hourly panels found")
    if windows[0][0] != expected_first:
        raise SystemExit(
            f"ERROR: {label} first hourly panel starts at "
            f"{windows[0][0]:%Y-%m-%d %H:%M} BJT; expected "
            f"{expected_first:%Y-%m-%d %H:%M} BJT (T13 after 12-hour spin-up)"
        )
    for index, (start, end) in enumerate(windows):
        if end - start != timedelta(hours=1):
            raise SystemExit(f"ERROR: {label} has non-hourly window {format_window((start, end))}")
        if index and start != windows[index - 1][1]:
            raise SystemExit(
                f"ERROR: {label} hourly sequence is discontinuous between "
                f"{format_window(windows[index - 1])} and {format_window((start, end))}"
            )


def format_window(window: tuple[datetime, datetime]) -> str:
    return f"{window[0]:%Y%m%d%H}-{window[1]:%Y%m%d%H}"


def format_windows(windows: list[tuple[datetime, datetime]]) -> str:
    if not windows:
        return "empty"
    return f"{len(windows)}:{format_window(windows[0])}..{format_window(windows[-1])}"


if __name__ == "__main__":
    main()
