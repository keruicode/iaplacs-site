"""Run on compute nodes: shared-source extraction must preserve cropped values."""

from pathlib import Path

import numpy as np
import pytest
import render_supercooled_water_path as renderer


def test_shared_source_extracted_once_per_time(monkeypatch):
    calls = []
    original = np.arange(20.0).reshape(4, 5)

    def extract(source, index):
        calls.append((source, index))
        return (
            original,
            original,
            {
                "cloud": original + index,
                "rain": original * 2 + index,
            },
            {"valid_utc": f"2026-11-13T{index:02d}:00:00+00:00"},
        )

    monkeypatch.setattr(renderer, "extract", extract)
    monkeypatch.setattr(
        renderer, "geographic_extent", lambda profile, area, *args: area
    )
    monkeypatch.setattr(
        renderer,
        "crop_indices",
        lambda lat, lon, area: (1, 2, 1, 3) if area == "regional" else (0, 3, 0, 4),
    )
    source = Path("wrfout_d01_sample")
    records, _, diagnostics = renderer.collect_source_records(
        source, ["regional", "wide"], [13, 14], "ningxia"
    )
    assert calls == [(source, 13), (source, 14)]
    assert len(diagnostics) == 4
    for i, index in enumerate([13, 14]):
        for kind, factor in [("cloud", 1), ("rain", 2)]:
            expected = original * factor + index
            np.testing.assert_array_equal(records["wide"][i][kind], expected)
            np.testing.assert_array_equal(
                records["regional"][i][kind], expected[1:3, 1:4]
            )
    assert not np.shares_memory(records["wide"][0]["lat"], original)
    assert records["regional"][0]["label"] == "11-13 21:00 BJT"


def test_invalid_columns_still_fail(monkeypatch):
    grid = np.ones((3, 3))
    monkeypatch.setattr(
        renderer,
        "extract",
        lambda *_: (
            grid,
            grid,
            {"cloud": grid * np.nan, "rain": grid},
            {"valid_utc": "2026-11-13T13:00:00+00:00"},
        ),
    )
    monkeypatch.setattr(renderer, "geographic_extent", lambda *args: (0, 1, 0, 1))
    monkeypatch.setattr(renderer, "crop_indices", lambda *args: (0, 2, 0, 2))
    with pytest.raises(ValueError, match="No valid"):
        renderer.collect_source_records(
            Path("wrfout_d02_sample"), ["regional"], [13], "yunnan"
        )
