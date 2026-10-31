"""Raw-VIS QC, instant times and OSS-only catalog regression tests."""

import json
import os
import subprocess
import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path

import numpy as np
import pytest
from build_forecast_catalog import build_airport_aviation_products, merge_existing_runs
from netCDF4 import Dataset
from render_work_visibility import (
    categories,
    is_current,
    quality_control,
    select_indices,
    visibility_variable,
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
    wrf_dir = tmp_path / "model/2026103006/gfs/wrf"
    wrf_dir.mkdir(parents=True)
    (wrf_dir / "wrfout_d01_2026-10-30_06:00:00").touch()
    (wrf_dir / "rsl.error.0000").write_text("Timing for main\n", encoding="utf-8")
    output = tmp_path / "products"
    script = Path(__file__).resolve().parents[1] / "publish_work_visibility.sh"
    result = subprocess.run(
        ["bash", str(script), "--run", "20261030_06"],
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


def test_vis_min_explicit_selection_and_first_layer(tmp_path):
    with Dataset(tmp_path / "fields.nc", "w") as ds:
        dims = ("Time", "bottom_top", "south_north", "west_east")
        for name, size in zip(dims, (1, 2, 4, 4)):
            ds.createDimension(name, size)
        old = ds.createVariable("VIS", "f4", dims)
        old.units = "m"
        old[:] = 10000
        assert visibility_variable(ds, "VIS_MIN") is None
        assert visibility_variable(ds, "auto").name == "VIS"
        new = ds.createVariable("VIS_MIN", "f4", dims)
        new.units = "m"
        new[:, 0] = 100
        new[:, 1] = 500
        selected = visibility_variable(ds, "VIS_MIN")
        assert visibility_variable(ds, "auto").name == "VIS_MIN"
        np.testing.assert_equal(selected[0, 0], 100)
        np.testing.assert_equal(ds["VIS"][0, 0], 10000)
        new.units = "km"
        with pytest.raises(ValueError, match="metres"):
            visibility_variable(ds, "VIS_MIN")


@pytest.mark.parametrize("profile", ["yunnan", "xinjiang"])
def test_regional_publisher_skips_missing_visibility(tmp_path, profile):
    wrf = tmp_path / "model/2026103100/gfs/wrf"
    wrf.mkdir(parents=True)
    (wrf / "rsl.error.0000").write_text("SUCCESS COMPLETE WRF\n", encoding="utf-8")
    for domain in ("d01", "d02"):
        with Dataset(wrf / f"wrfout_{domain}_2026-10-31_00:00:00", "w") as ds:
            ds.createDimension("Time", 25)
    script = Path(__file__).resolve().parents[1] / "publish_work_visibility.sh"
    result = subprocess.run(
        ["bash", str(script), "--run", "20261031_00", "--profile", profile],
        env={
            **os.environ,
            "PYTHON_BIN": sys.executable,
            "WORK_VISIBILITY_MODEL_ROOT": str(tmp_path / "model"),
            "WORK_VISIBILITY_OUTPUT_ROOT": str(tmp_path / "products"),
            "IAPLACS_PUBLISH_VISIBILITY": "1",
        },
        capture_output=True,
        text=True,
        check=True,
    )
    assert "no supported visibility field" in result.stdout
    assert not (tmp_path / "products").exists()


@pytest.mark.parametrize(
    "service,family,prefix,product_id",
    [
        ("airport", "airport_yunnan", "airport_yunnan_", "airport_visibility"),
        ("xinjiang", "workxj_summary", "", "xinjiang_visibility"),
    ],
)
def test_regional_visibility_catalog_without_rain_assets(
    tmp_path, monkeypatch, service, family, prefix, product_id
):
    import build_forecast_catalog as catalog

    monkeypatch.setattr(catalog, "ROOT", tmp_path)
    monkeypatch.setattr(catalog, "yunnan_airport_run_is_complete", lambda run: True)
    run_id = "20261031_00"
    directory = tmp_path / "data/current/maps" / f"{family}_{run_id}" / "visibility"
    directory.mkdir(parents=True)
    (directory / "one.png").write_bytes(b"fixture")
    (directory / "production_manifest.json").write_text(
        json.dumps(
            {
                "products": [
                    {
                        "id": product_id,
                        "title": "能见度",
                        "unit": "VIS_MIN",
                        "frames": [
                            {
                                "id": "visibility_region",
                                "file": "one.png",
                                "time_kind": "instant",
                                "individual_frames": [
                                    {"file": "one.png", "time_kind": "instant"}
                                ],
                            }
                        ],
                    }
                ]
            }
        ),
        encoding="utf-8",
    )
    run = {"id": prefix + run_id, "run_time": "2026-10-31T00:00:00Z", "products": []}
    existing = {"services": {service: {"runs": [run]}}}
    merged = merge_existing_runs([], existing, service, id_prefix=prefix)
    assert merged[0]["products"][0]["id"] == product_id
    assert merged[0]["products"][0]["color"] == "#0f68c8"
    (directory / "production_manifest.json").unlink()
    retained = merge_existing_runs(
        [{**run, "products": []}],
        {"services": {service: {"runs": merged}}},
        service,
        id_prefix=prefix,
    )
    assert retained[0]["products"][0]["id"] == product_id


def test_reserved_profiles_default_to_vis_min():
    from render_work_visibility import build_parser

    for profile in ("ningxia", "yunnan", "xinjiang"):
        args = build_parser().parse_args(
            [
                "--input",
                "input.nc",
                "--output",
                "preview",
                "--province-shp",
                "p.shp",
                "--profile",
                profile,
                "--domain",
                "d02",
            ]
        )
        assert args.variable == "VIS_MIN"
        assert args.domain == "d02"


def test_montage_can_hide_104_label_without_removing_tick():
    import matplotlib.pyplot as plt
    from render_work_visibility import draw_panel

    lon, lat = np.meshgrid(np.linspace(104, 107.8, 5), np.linspace(35, 39.7, 5))
    figure, axes = plt.subplots(1, 2)
    try:
        for axis, omit in zip(axes, (False, True)):
            draw_panel(
                axis,
                lon,
                lat,
                np.zeros_like(lon),
                (104, 107.8, 35, 39.7),
                [],
                [],
                omit_104_label=omit,
            )
        assert axes[0].get_xticklabels()[0].get_text() == "104°E"
        assert axes[1].get_xticklabels()[0].get_text() == ""
        np.testing.assert_equal(axes[1].get_xticks(), [104, 105, 106, 107])
    finally:
        plt.close(figure)


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
