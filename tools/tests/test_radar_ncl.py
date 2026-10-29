"""Checks for the isolated mass-field radar diagnostic."""

import numpy as np
import pytest
from render_yunnan_radar_ncl import INPUTS, checked_inputs


def fixture_fields():
    fields = {name: np.zeros((1, 3, 4, 5)) for name in INPUTS}
    fields["PB"][:] = 90000
    fields["QRAIN"][:] = 0.001
    return fields


def test_mass_inputs_do_not_use_native_dbz_or_mutate_negative_q():
    ds = fixture_fields()
    ds["DBZ"] = np.full((1, 3, 4, 5), 212.0)
    ds["QSNOW"][0, 1, 1, 1] = -1e-12
    inputs, negatives = checked_inputs(ds, 0)
    assert "DBZ" not in inputs
    assert negatives["QSNOW"] == 1
    assert ds["QSNOW"][0, 1, 1, 1] == -1e-12
    assert inputs["P"].shape == (3, 4, 5)


@pytest.mark.parametrize("name", INPUTS)
def test_nonfinite_mass_input_is_rejected(name):
    ds = fixture_fields()
    ds[name][0, 1, 1, 1] = np.nan
    with pytest.raises(ValueError, match="Nonfinite"):
        checked_inputs(ds, 0)


def test_bad_pressure_and_mismatched_grid_fail():
    ds = fixture_fields()
    ds["PB"][:] = 0
    with pytest.raises(ValueError, match="pressure"):
        checked_inputs(ds, 0)
    ds = fixture_fields()
    ds["QRAIN"] = np.zeros((1, 2, 4, 5))
    with pytest.raises(ValueError, match="grids differ"):
        checked_inputs(ds, 0)


@pytest.mark.parametrize("value", [40.0, 212.0, np.nan])
def test_diagnostic_rejects_bad_output_and_cleans_temporary_files(
    tmp_path, monkeypatch, value
):
    from pathlib import Path
    from types import SimpleNamespace

    from netCDF4 import Dataset
    from render_yunnan_radar_ncl import diagnose

    def fake_ncl(command, **kwargs):
        target = Path(command[3].split('"')[1])
        with Dataset(target, "w") as ds:
            ds.createDimension("y", 4)
            ds.createDimension("x", 5)
            ds.createVariable("DBZ_MAX", "f8", ("y", "x"))[:] = value
        return SimpleNamespace(stdout="", stderr="")

    monkeypatch.setattr("render_yunnan_radar_ncl.subprocess.run", fake_ncl)
    fields, _ = checked_inputs(fixture_fields(), 0)
    args = (fields, Path("/example/bin/ncl"), Path("diagnostic.ncl"), tmp_path)
    if value == 40:
        np.testing.assert_equal(diagnose(*args), np.full((4, 5), 40.0))
    else:
        with pytest.raises(ValueError):
            diagnose(*args)
    assert not list(tmp_path.iterdir())
