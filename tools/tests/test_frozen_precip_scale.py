"""Keep frozen thresholds and labels consistent across all forecast templates."""

import re
from pathlib import Path

import pytest

TOOLS = Path(__file__).resolve().parents[1]
SCRIPTS = (
    "rain_worknx_national_hour_bjt.ncl",
    "rain_worknx_ningxia_hour_bjt.ncl",
    "rain_worknx_yunnan_airport_hour_bjt.ncl",
    "rain_wrf_hour_bjt.ncl",
)
LEVELS = [0.1, 0.5, 1, 2.5, 5, 10, 15, 20]


@pytest.mark.parametrize("name", SCRIPTS)
def test_frozen_scale_and_labels(name):
    source = (TOOLS / name).read_text(encoding="utf-8")
    block = source.split('if (component_mode.eq."frozen") then', 1)[1].split(
        "else if", 1
    )[0]
    levels = re.search(r"rain_levs = \(/(.*?)/\)", block).group(1)
    colors = re.search(r"fill_colors = \(/(.*?)/\)", block).group(1)
    assert [float(v) for v in levels.split(",")] == LEVELS
    colors = [int(v) for v in colors.split(",")]
    assert colors == [2, 3, 4, 5, 6, 7, 8, 9, 9]
    assert len(colors) == len(LEVELS) + 1
    assert '(/"0.1", "0.5", "1", "2.5", "5", "10", "15", "20"/)' in source
    assert "rain_levs = (/0.0, 2.5, 5.0, 10.0, 25.0, 50.0, 100.0/)" in source
    assert 'res@lbOrientation = "Vertical"' in source
