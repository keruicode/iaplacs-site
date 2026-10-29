"""Raw-VIS QC, instant times and OSS-only catalog regression tests."""

import json
import os
import subprocess
from datetime import UTC, datetime, timedelta
from pathlib import Path

import numpy as np
import pytest
from build_forecast_catalog import build_airport_aviation_products, merge_existing_runs
from render_work_visibility import (
    categories,
    is_current,
    quality_control,
    select_indices,
)


def test_qc_preserves_values_and_separates_invalid_cells():
    raw = np.full((7, 7), 10000.0)
    raw[1, 1:6] = [np.nan, -1, 0, 1e17, 100000]
    raw[2, 1:6] = [1, 50, 100, 500, 1000]
    original = raw.copy()
    clean, stats = quality_control(raw)
    np.testing.assert_equal(raw, original)
    assert stats["boundary_cells"] == 24
    assert stats["missing_interior"] == 1
    assert stats["nonpositive_interior"] == 2
    assert stats["over_100km_interior"] == 1
    assert clean[1, 5] == 100000
    assert clean[3, 3] == 10000
    assert categories(clean)[1, 4] == 6
    assert categories(clean)[3, 3] == 5
    np.testing.assert_equal(categories(clean)[2, 1:6], [0, 1, 2, 4, 5])


def test_masked_input_is_not_filled_with_clear_visibility():
    raw = np.ma.array(np.full((4, 4), 10.0), mask=False)
    raw.mask[1, 1] = True
    clean, stats = quality_control(raw)
    assert clean.mask[1, 1]
    assert stats["missing_interior"] == 1


@pytest.mark.parametrize("raw", [np.zeros((4, 4)), np.full((4, 4), 1e17)])
def test_unusable_hour_fails_closed(raw):
    with pytest.raises(ValueError, match="no valid interior"):
        quality_control(raw)


def test_actual_times_not_assumed_hourly_indices():
    start = datetime(2026, 10, 27, 6, tzinfo=UTC)
    times = [start + timedelta(minutes=30 * i) for i in range(31)]
    assert select_indices(times, 13, 3) == [26, 27, 28]
    with pytest.raises(ValueError):
        select_indices(times[::-1], 13, 3)
    with pytest.raises(ValueError):
        select_indices(times, 12, 3)


def test_cache_requires_matching_source_and_every_image(tmp_path):
    signature = {"source": "test", "mtime_ns": 1}
    manifest = tmp_path / "production_manifest.json"
    manifest.write_text("invalid", encoding="utf-8")
    assert not is_current(tmp_path, signature)
    manifest.write_text(
        json.dumps(
            {
                "source_signature": signature,
                "products": [
                    {
                        "frames": [
                            {
                                "file": "montage.png",
                                "individual_frames": [{"file": "hour.png"}],
                            }
                        ]
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    (tmp_path / "montage.png").touch()
    assert not is_current(tmp_path, signature)
    (tmp_path / "hour.png").touch()
    assert is_current(tmp_path, signature)
    assert not is_current(tmp_path, {**signature, "mtime_ns": 2})


def test_publisher_does_not_render_or_upload_incomplete_run(tmp_path):
    wrf_dir = tmp_path / "model/2026102718/gfs/wrf"
    wrf_dir.mkdir(parents=True)
    (wrf_dir / "wrfout_d01_2026-10-27_18:00:00").touch()
    (wrf_dir / "rsl.error.0000").write_text("Timing for main\n", encoding="utf-8")
    output = tmp_path / "products"
    script = Path(__file__).resolve().parents[1] / "publish_work_visibility.sh"
    result = subprocess.run(
        ["bash", str(script), "--run", "20261027_18"],
        env={
            **os.environ,
            "WORK_VISIBILITY_MODEL_ROOT": str(tmp_path / "model"),
            "WORK_VISIBILITY_OUTPUT_ROOT": str(output),
            "PYTHON_BIN": "/usr/bin/false",
            "IAPLACS_PUBLISH_VISIBILITY": "1",
        },
        check=True,
        capture_output=True,
        text=True,
    )
    assert "waiting for completed WRF" in result.stdout
    assert not output.exists()


def test_visibility_publication_can_be_disabled_by_operator():
    script = Path(__file__).resolve().parents[1] / "publish_work_visibility.sh"
    env = {
        key: value
        for key, value in os.environ.items()
        if key != "IAPLACS_PUBLISH_VISIBILITY"
    }
    env["IAPLACS_PUBLISH_VISIBILITY"] = "0"
    result = subprocess.run(
        ["bash", str(script), "--run", "20261027_06"],
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )
    assert "publication disabled" in result.stdout


def test_catalog_keeps_visibility_after_upload_staging_cleanup(tmp_path, monkeypatch):
    import build_forecast_catalog as catalog

    monkeypatch.setattr(catalog, "ROOT", tmp_path)
    run = tmp_path / "data/current/maps/worknx_summary_20261027_06"
    diagnostic = run / "visibility"
    diagnostic.mkdir(parents=True)
    (diagnostic / "one.png").write_bytes(b"fixture")
    frame = {
        "file": "one.png",
        "valid_time": "2026-10-28T03:00:00+08:00",
        "time_kind": "instant",
    }
    (diagnostic / "production_manifest.json").write_text(
        json.dumps(
            {
                "products": [
                    {
                        "id": "ningxia_visibility",
                        "title": "能见度",
                        "description": "VIS QC",
                        "frames": [{**frame, "individual_frames": [frame]}],
                    }
                ]
            }
        ),
        encoding="utf-8",
    )
    products = build_airport_aviation_products(
        run,
        "20261027_06",
        "2026-10-28T00:00:00Z",
        category="中国中东部",
        asset_subdir="visibility",
    )
    assert products[0]["frames"][0]["individual_frames"][0]["time_kind"] == "instant"
    assert products[0]["description"] == "VIS QC"
    existing = {
        "services": {
            "ningxia": {
                "runs": [
                    {
                        "id": "20261027_06",
                        "run_time": "2026-10-27T06:00:00Z",
                        "products": products,
                    }
                ]
            }
        }
    }
    merged = merge_existing_runs(
        [{"id": "20261027_06", "products": []}], existing, "ningxia"
    )
    assert merged[0]["products"][0]["id"] == "ningxia_visibility"
