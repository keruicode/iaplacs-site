import numpy as np
import pytest
from cloud_visibility_moments import (
    cloud_groups,
    extinction,
    visibility_from_extinction,
)
from netCDF4 import Dataset
from render_cloud_visibility_preview import diagnose, dry_air_density
from render_work_visibility import draw_panel
from visibility_source import select_source


def inputs():
    return {
        n: np.full((3, 4), v)
        for n, v in {
            "P": 1000.0,
            "PB": 99000.0,
            "T": 0.0,
            "QVAPOR": 0.01,
            "QCLOUD": 1e-4,
            "NW": 1e8,
            "NW_Z": 0.01,
        }.items()
    }


def test_density():
    assert dry_air_density(np.array([100000.0]), np.array([300.0]), np.array([0.0]))[
        0
    ] == pytest.approx(100000 / (287 * 300))
    with pytest.raises(ValueError):
        dry_air_density(np.array([-1.0]), np.array([300.0]), np.array([0.0]))


def test_cloud_formula_and_nonmutation():
    fields = inputs()
    before = {n: a.copy() for n, a in fields.items()}
    result, stats = diagnose(fields, cloud_groups(fields))
    rho = dry_air_density(
        fields["P"] + fields["PB"], fields["T"] + 300, fields["QVAPOR"]
    )
    expected = visibility_from_extinction(
        extinction(fields["QCLOUD"], fields["NW"], fields["NW_Z"], rho)
    )
    np.testing.assert_allclose(result, expected)
    assert stats["invalid_input_cells"] == 0
    for n in fields:
        np.testing.assert_array_equal(fields[n], before[n])


def test_clear_missing_and_inconsistent_cloud():
    fields = inputs()
    fields["QCLOUD"][0, 0] = 0
    fields["NW"][0, 1] = np.nan
    fields["NW_Z"][0, 2] = 0
    fields["QCLOUD"][0, 3] = -1e-5
    fields["QCLOUD"][1, 0] = -1e-15
    result, stats = diagnose(fields, cloud_groups(fields))
    assert result[0, 0] == 100000
    assert result[1, 0] == 100000
    assert result.mask[0, 1:4].all()
    assert stats["tiny_negative_mixing_ratios_treated_as_zero"] == 1


def test_empty_and_incomplete_fail():
    fields = inputs()
    fields["P"][:] = np.nan
    with pytest.raises(ValueError, match="No valid"):
        diagnose(fields, cloud_groups(fields))
    with pytest.raises(ValueError):
        cloud_groups(["QCLOUD", "NW"])


def test_xinjiang_map_ticks():
    import matplotlib.pyplot as plt

    lon, lat = np.meshgrid(np.linspace(72, 98, 4), np.linspace(34, 50, 4))
    figure, axis = plt.subplots()
    draw_panel(
        axis, lon, lat, np.ones((4, 4)), (72, 98, 34, 50), [], [], xinjiang_ticks=True
    )
    np.testing.assert_array_equal(axis.get_xticks(), [72, 80, 88, 96])
    np.testing.assert_array_equal(axis.get_yticks(), [34, 38, 42, 46, 50])
    plt.close(figure)


@pytest.mark.parametrize("profile", ["yunnan", "xinjiang"])
def test_selection_upgrades_diagnostic_to_native(tmp_path, profile):
    d01 = tmp_path / "wrfout_d01_example"
    d02 = tmp_path / "wrfout_d02_example"
    dims = ("Time", "bottom_top", "south_north", "west_east")
    with Dataset(d02, "w") as ds:
        for n, size in zip(dims, [25, 1, 3, 3]):
            ds.createDimension(n, size)
        for n in inputs():
            ds.createVariable(n, "f4", dims)
    assert select_source(d01, profile) == (d02, "diagnostic")
    with Dataset(d02, "a") as ds:
        ds.createVariable("VIS", "f4", dims).units = "m"
    assert select_source(d01, profile) == (d02, "native")
    with Dataset(d02, "a") as ds:
        ds.createVariable("VIS_MIN", "f4", dims).units = "m"
    assert select_source(d01, profile) == (d02, "native")
    assert select_source(d01, "ningxia") is None


def test_native_bypasses_diagnostic_cache(tmp_path, monkeypatch):
    import render_cloud_visibility_preview as preview

    source = tmp_path / "source.nc"
    dims = ("Time", "bottom_top", "south_north", "west_east")
    with Dataset(source, "w") as ds:
        for n, size in zip(dims, [25, 1, 3, 3]):
            ds.createDimension(n, size)
        ds.createVariable("VIS_MIN", "f4", dims).units = "m"
    shp = tmp_path / "map.shp"
    shp.touch()
    called = []
    monkeypatch.setattr(
        preview, "render", lambda args: called.append(args.variable) or 0
    )
    monkeypatch.setattr(
        preview,
        "is_current",
        lambda *args: pytest.fail("native must be checked before diagnostic cache"),
    )
    assert (
        preview.main(
            [
                "--input",
                str(source),
                "--output",
                str(tmp_path / "out"),
                "--province-shp",
                str(shp),
                "--profile",
                "yunnan",
                "--production",
                "--if-needed",
            ]
        )
        == 0
    )
    assert called == ["auto"]
