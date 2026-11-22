"""Synthetic, local-only regression tests for the downloadable numerical fields."""

from pathlib import Path

import numpy as np
import pytest
from export_ningxia_download import export
from netCDF4 import Dataset, stringtochar


def source_file(path: Path) -> None:
    from datetime import datetime, timedelta

    with Dataset(path, "w") as ds:
        for name, size in (
            ("Time", 37),
            ("DateStrLen", 19),
            ("south_north", 5),
            ("west_east", 6),
            ("bottom_top", 2),
        ):
            ds.createDimension(name, size)
        times = np.array(
            [
                (datetime(2026, 11, 22) + timedelta(hours=i)).strftime(
                    "%Y-%m-%d_%H:%M:%S"
                )
                for i in range(37)
            ],
            dtype="S19",
        )
        ds.createVariable("Times", "S1", ("Time", "DateStrLen"))[:] = stringtochar(
            times
        )
        dims = ("Time", "south_north", "west_east")
        lon, lat = np.meshgrid(np.linspace(103, 109, 6), np.linspace(34, 41, 5))
        for name, values in (("XLAT", lat), ("XLONG", lon)):
            ds.createVariable(name, "f4", dims)[:] = values
        for name, factor in (
            ("RAINC", 1),
            ("RAINNC", 2),
            ("GRAUPELNC", 0.5),
            ("HAILNC", 0.25),
            ("SNOWNC", 0.75),
        ):
            v = ds.createVariable(name, "f4", dims)
            v.units = "mm"
            v[:] = np.arange(37)[:, None, None] * factor
        dims4 = ("Time", "bottom_top", "south_north", "west_east")
        v = ds.createVariable("VIS_MIN", "f4", dims4)
        v.units = "m"
        v[:] = 3000
        v = ds.createVariable("DBZ", "f4", dims4)
        v.units = "dBZ"
        v[:] = 20
        v[:, 0, 2, 2] = 199
        ds.GRID_ID = 1


def test_export_values_time_crop_and_cache(tmp_path: Path) -> None:
    import json

    source = tmp_path / "wrfout_d01_test"
    source_file(source)
    index = export(source, tmp_path / "download")
    metadata = json.loads(index.read_text())
    target = index.parent / metadata["file"]
    before = target.stat().st_mtime_ns
    with Dataset(target) as ds:
        assert ds["precipitation_1h"].shape == (24, 3, 3)
        np.testing.assert_allclose(ds["precipitation_1h"][:].compressed(), 3.75)
        np.testing.assert_allclose(ds["solid_precipitation_1h"][:].compressed(), 1.5)
        np.testing.assert_allclose(ds["composite_reflectivity"][:].compressed(), 20)
        np.testing.assert_allclose(ds["visibility"][:].compressed(), 3000)
        assert ds["visibility"].source_variable == "VIS_MIN"
        np.testing.assert_allclose(ds["hour_bounds"][0], [12, 13])
        np.testing.assert_allclose(ds["bounds_24h"][:], [[12, 36]])
        np.testing.assert_allclose(ds["precipitation_24h"][:].compressed(), 90)
        assert ds["precipitation_1h"].filters()["zlib"]
    export(source, index.parent)
    assert target.stat().st_mtime_ns == before


def test_invalid_units_do_not_publish(tmp_path: Path) -> None:
    source = tmp_path / "wrfout"
    source_file(source)
    with Dataset(source, "a") as ds:
        ds["RAINC"].units = "m"
    with pytest.raises(ValueError, match="units"):
        export(source, tmp_path / "download")
    assert not (tmp_path / "download/index.json").exists()
    assert not (tmp_path / "download/.ningxia.partial.nc").exists()
