"""Regional radar metadata, plotting markers, and retained catalog coverage."""

import json
from datetime import UTC, datetime, timedelta
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pytest
from netCDF4 import Dataset

import build_forecast_catalog as catalog
import render_yunnan_radar as radar


@pytest.mark.parametrize(
    "profile,planes", [("yunnan", 8), ("ningxia", 0), ("xinjiang", 2)]
)
def test_profile_map_and_manifest(tmp_path, monkeypatch, profile, planes):
    config = radar.RADAR_PROFILES[profile]
    west, east, south, north = config["default_region"]
    lon, lat = np.meshgrid(np.linspace(west, east, 7), np.linspace(south, north, 7))
    fig, ax = plt.subplots()
    radar.draw_panel(
        ax,
        lon,
        lat,
        np.ma.array(np.full((7, 7), 30.0)),
        config["default_region"],
        [],
        [],
        profile=profile,
    )
    assert len(ax.patches) == planes
    assert 2 <= len(ax.get_xticks()) <= 7
    plt.close(fig)

    source = tmp_path / "wrfout.nc"
    with Dataset(source, "w") as ds:
        for name, size in [
            ("Time", 14),
            ("bottom_top", 2),
            ("south_north", 7),
            ("west_east", 7),
        ]:
            ds.createDimension(name, size)
        dims = ("Time", "south_north", "west_east")
        ds.createVariable("XLAT", "f4", dims)[:] = lat
        ds.createVariable("XLONG", "f4", dims)[:] = lon
        dbz = ds.createVariable(
            "DBZ", "f4", ("Time", "bottom_top", "south_north", "west_east")
        )
        dbz.units = "dBZ"
        dbz[:] = 30
    monkeypatch.setattr(radar, "source_signature", lambda *a: {"profile": profile})
    monkeypatch.setattr(radar, "shp_lines", lambda *a: [])
    monkeypatch.setattr(
        radar,
        "wrf_times",
        lambda ds: [
            datetime(2026, 11, 7, tzinfo=UTC) + timedelta(hours=i) for i in range(14)
        ],
    )

    def capture_maps(*args, **kwargs):
        assert kwargs["profile"] == profile
        assert np.all(args[3][0].compressed() == 30)
        return {"id": config["id"] + "_region", "file": "fixture.png"}

    monkeypatch.setattr(radar, "save_maps", capture_maps)
    output = tmp_path / "radar"
    args = radar.build_parser().parse_args(
        [
            "--input",
            str(source),
            "--output",
            str(output),
            "--province-shp",
            str(tmp_path / "unused.shp"),
            "--profile",
            profile,
        ]
    )
    assert radar.render(args) == 0
    manifest = json.loads((output / "production_manifest.json").read_text())
    assert manifest["products"][0]["id"] == config["id"]
    assert manifest["source_variable"] == "DBZ"
    assert manifest["aggregation"] == "vertical_maximum"
    assert manifest["extent"] == list(config["default_region"])


@pytest.mark.parametrize(
    "service,family", [("ningxia", "worknx_summary"), ("xinjiang", "workxj_summary")]
)
def test_radar_catalog_attach_and_preserve(tmp_path, monkeypatch, service, family):
    monkeypatch.setattr(catalog, "ROOT", tmp_path)
    run_id = "20261107_00"
    output = tmp_path / "data/current/maps" / f"{family}_{run_id}" / "radar"
    output.mkdir(parents=True)
    (output / "one.png").write_bytes(b"fixture")
    product = {
        "id": f"{service}_radar",
        "title": "雷达回波",
        "unit": "组合反射率（dBZ）",
        "frames": [
            {
                "file": "one.png",
                "time_kind": "instant",
                "individual_frames": [{"file": "one.png"}],
            }
        ],
    }
    (output / "production_manifest.json").write_text(
        json.dumps({"products": [product]})
    )
    run = {"id": run_id, "run_time": "2026-11-07T00:00:00Z", "products": []}
    merged = catalog.merge_existing_runs(
        [], {"services": {service: {"runs": [run]}}}, service
    )
    assert merged[0]["products"][0]["id"] == product["id"]
    assert len(merged[0]["products"][0]["frames"][0]["individual_frames"]) == 1
    (output / "production_manifest.json").unlink()
    retained = catalog.merge_existing_runs(
        [run.copy() | {"products": []}],
        {"services": {service: {"runs": merged}}},
        service,
    )
    assert retained[0]["products"][0]["id"] == product["id"]


def test_frontend_and_auditor_enable_both_profiles():
    root = Path(__file__).resolve().parents[2]
    app = (root / "app.js").read_text()
    audit = (root / "tools/audit_iap_forecast_publication.sh").read_text()
    for profile in ("ningxia", "xinjiang"):
        assert f'"{profile}_radar"' in app
        assert f"--profile {profile} --run" in audit
