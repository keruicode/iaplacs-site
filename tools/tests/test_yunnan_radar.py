"""Scientific reduction, source selection and catalog radar regressions."""

import json

import numpy as np
import pytest
from build_forecast_catalog import build_airport_aviation_products
from render_yunnan_radar import composite_reflectivity


def test_nmc_palette_and_white_missing_display():
    from render_yunnan_radar import INVALID_COLOR, LEVELS, RADAR_COLORS

    np.testing.assert_equal(LEVELS, np.arange(5, 75, 5))
    assert len(RADAR_COLORS) == len(LEVELS) - 1
    assert RADAR_COLORS[0] == "#419df1"
    assert RADAR_COLORS[8] == "#ff0000"
    assert INVALID_COLOR == "#ffffff"


def test_column_maximum_is_not_sum_or_lowest_level():
    raw = np.full((3, 5, 5), -150.0)
    raw[:, 2, 2] = [10, 40, 20]
    original = raw.copy()
    composite, stats = composite_reflectivity(raw)
    assert composite[2, 2] == 40
    assert composite[1, 1] == -150
    assert composite.mask[0, :].all()
    assert stats["valid_composite_max_dbz"] == 40
    np.testing.assert_equal(raw, original)


@pytest.mark.parametrize("invalid", [np.nan, np.inf, 305.24, -151])
def test_one_bad_level_invalidates_entire_column(invalid):
    raw = np.full((3, 5, 5), 20.0)
    raw[0, 2, 2] = invalid
    composite, stats = composite_reflectivity(raw)
    assert composite.mask[2, 2]
    assert composite[1, 1] == 20
    assert stats["suspect_interior_columns"] == 1


def test_all_missing_fails_and_strong_valid_values_are_not_clipped():
    with pytest.raises(ValueError, match="No valid"):
        composite_reflectivity(np.full((3, 5, 5), np.nan))
    raw = np.full((3, 5, 5), 100.0)
    composite, _ = composite_reflectivity(raw)
    assert composite[2, 2] == 100


def test_radar_manifest_has_instant_times(tmp_path, monkeypatch):
    import build_forecast_catalog as catalog

    monkeypatch.setattr(catalog, "ROOT", tmp_path)
    run_dir = tmp_path / "data/current/maps/airport_yunnan_20261027_06"
    radar = run_dir / "radar"
    radar.mkdir(parents=True)
    (radar / "one.png").write_bytes(b"fixture")
    frame = {
        "file": "one.png",
        "time_kind": "instant",
        "valid_time": "2026-10-28T03:00:00+08:00",
    }
    (radar / "production_manifest.json").write_text(
        json.dumps(
            {
                "products": [
                    {
                        "id": "airport_radar",
                        "title": "模拟雷达回波",
                        "frames": [{**frame, "individual_frames": [frame]}],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    products = build_airport_aviation_products(
        run_dir,
        "20261027_06",
        "2026-10-28T00:00:00Z",
        category="机场服务",
        asset_subdir="radar",
    )
    assert products[0]["frames"][0]["individual_frames"][0]["time_kind"] == "instant"

    monkeypatch.setattr(catalog, "yunnan_airport_run_is_complete", lambda run: True)
    rain = {"id": "airport_yunnan_precip_series", "frames": []}
    original = {
        "id": "airport_yunnan_20261027_06",
        "run_time": "2026-10-27T06:00:00Z",
        "products": [rain],
    }
    existing = {"services": {"airport": {"runs": [original]}}}
    merged = catalog.merge_existing_runs(
        [], existing, "airport", id_prefix="airport_yunnan_"
    )
    assert [p["id"] for p in merged[0]["products"]] == [rain["id"], "airport_radar"]
    (radar / "production_manifest.json").unlink()
    retained = catalog.merge_existing_runs(
        [{**original, "products": [rain]}],
        {"services": {"airport": {"runs": merged}}},
        "airport",
        id_prefix="airport_yunnan_",
    )
    assert "airport_radar" in [p["id"] for p in retained[0]["products"]]
    assert retained[0]["products"][-1]["title"] == "雷达回波"


def test_visibility_retained_product_uses_blue(tmp_path, monkeypatch):
    import build_forecast_catalog as catalog

    monkeypatch.setattr(catalog, "ROOT", tmp_path)
    run = {
        "id": "20261027_18",
        "run_time": "2026-10-27T18:00:00Z",
        "products": [{"id": "ningxia_visibility", "color": "#687d98"}],
    }
    merged = catalog.merge_existing_runs([run], {"services": {}}, "ningxia")
    assert merged[0]["products"][0]["color"] == "#0f68c8"


def test_solid_precipitation_labels_preserve_assets():
    from build_forecast_catalog import normalize_solid_precipitation_labels

    product = {
        "description": "可切换冰雹预警图。",
        "frames": [
            {"id": "hail_warning", "lead_label": "冰雹预警", "file": "hail_warning.png"}
        ],
    }
    normalize_solid_precipitation_labels(product)
    assert product["description"] == "可切换固态降水图。"
    assert product["frames"][0] == {
        "id": "hail_warning",
        "lead_label": "固态降水",
        "file": "hail_warning.png",
    }
