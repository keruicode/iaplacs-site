"""Small synthetic WRF fixture; run with other numerical tests on compute nodes."""

from datetime import datetime, timedelta

import numpy as np
import pytest
from netCDF4 import Dataset, stringtochar
from supercooled_wrf_io import DIM3, DIMW, UNITS, extract


def wrf_fixture(path):
    with Dataset(path, "w") as ds:
        for name, size in (
            ("Time", 14),
            ("bottom_top", 2),
            ("bottom_top_stag", 3),
            ("south_north", 3),
            ("west_east", 3),
            ("DateStrLen", 19),
        ):
            ds.createDimension(name, size)
        time = ds.createVariable("Times", "S1", ("Time", "DateStrLen"))
        labels = [
            (datetime(2026, 11, 12, 18) + timedelta(hours=i)).strftime(
                "%Y-%m-%d_%H:%M:%S"
            )
            for i in range(14)
        ]
        time[:] = stringtochar(np.asarray(labels, dtype="S19"))
        for name, units in UNITS.items():
            staggered = name in ("PH", "PHB")
            var = ds.createVariable(name, "f8", DIMW if staggered else DIM3)
            var.units = sorted(units)[0]
            value = {
                "T": -30,
                "P": 100000,
                "PB": 0,
                "QVAPOR": 0,
                "QCLOUD": 1e-4,
                "QRAIN": 2e-4,
                "PH": 0,
                "PHB": 0,
            }[name]
            var[:] = value
            if name == "PH":
                var[:] = np.array([0, 981, 1962])[None, :, None, None]
        ds["T"].description = "perturbation potential temperature (theta-t0)"
        for name, low in (("XLAT", 35), ("XLONG", 104)):
            var = ds.createVariable(name, "f8", ("Time", "south_north", "west_east"))
            var[:] = low + np.arange(3)[None, :, None] * 0.1


def test_extraction_units_and_whole_column(tmp_path):
    path = tmp_path / "wrfout.nc"
    wrf_fixture(path)
    lon, lat, fields, info = extract(path, 13)
    assert lon.shape == lat.shape == fields["cloud"].shape == (3, 3)
    expected = 1000 * (100000 / (287 * 270)) * 1e-4 * 200
    np.testing.assert_allclose(fields["cloud"], expected)
    np.testing.assert_allclose(fields["rain"], 2 * expected)
    assert info["valid_bjt"] == "2026-11-13 15:00 BJT"
    with Dataset(path, "a") as ds:
        ds["QCLOUD"].units = "g/kg"
    with pytest.raises(ValueError, match="dimensions/units"):
        extract(path, 13)


def test_incomplete_or_wrong_temperature_definition(tmp_path):
    path = tmp_path / "wrfout.nc"
    wrf_fixture(path)
    with pytest.raises(ValueError, match="spin-up"):
        extract(path, 1)
    with Dataset(path, "a") as ds:
        ds["T"].description = "moist potential temperature"
    with pytest.raises(ValueError, match="dry perturbation"):
        extract(path, 13)
