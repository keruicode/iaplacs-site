"""Synthetic, local-only regression tests for the downloadable numerical fields."""

from pathlib import Path

import numpy as np
import pytest
from export_ningxia_download import export
from netCDF4 import Dataset, chartostring, stringtochar


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
        assert ds["RAIN_1H"].shape == (24, 3, 3)
        assert ds["RAIN_1H"].dimensions == ("Time", "south_north", "west_east")
        assert ds["XLAT"].shape == (24, 3, 3)
        assert not any("bound" in key for key in ds.variables)
        np.testing.assert_allclose(ds["RAIN_1H"][:].compressed(), 3.75)
        np.testing.assert_allclose(ds["SOLID_1H"][:].compressed(), 1.5)
        np.testing.assert_allclose(ds["MDBZ"][:].compressed(), 20)
        np.testing.assert_allclose(ds["VIS_MIN"][:].compressed(), 3000)
        assert ds["VIS_MIN"].source_variable == "VIS_MIN"
        assert chartostring(ds["Times"][:])[0] == "2026-11-22_13:00:00"
        assert chartostring(ds["Times_START"][:])[0] == "2026-11-22_12:00:00"
        assert chartostring(ds["Times_24H"][:])[0] == "2026-11-23_12:00:00"
        assert chartostring(ds["Times_24H_START"][:])[0] == "2026-11-22_12:00:00"
        np.testing.assert_allclose(ds["XTIME"][:], np.arange(13, 37) * 60)
        np.testing.assert_allclose(ds["RAIN_24H"][:].compressed(), 90)
        assert ds["RAIN_1H"].filters()["zlib"]
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


def test_vis_fallback_keeps_actual_variable_name(tmp_path: Path) -> None:
    import json

    source = tmp_path / "wrfout_d02_test"
    source_file(source)
    with Dataset(source, "a") as ds:
        ds.renameVariable("VIS_MIN", "VIS")
        ds.GRID_ID = 2
    index = export(source, tmp_path / "download")
    metadata = json.loads(index.read_text())
    assert metadata["domain"] == "d02"
    with Dataset(index.parent / metadata["file"]) as ds:
        assert "VIS_MIN" not in ds.variables
        assert ds["VIS"].time_kind == "instantaneous"
        np.testing.assert_allclose(ds["VIS"][:].compressed(), 3000)


def test_recent_counts_completed_runs(tmp_path: Path, monkeypatch) -> None:
    import os
    import shutil
    import subprocess

    scripts = tmp_path / "scripts"
    scripts.mkdir()
    bins = tmp_path / "bin"
    bins.mkdir()
    script = Path(__file__).parents[1] / "publish_ningxia_downloads.sh"
    shutil.copy2(script, scripts / script.name)
    (scripts / "runtime_paths.sh").write_text(
        f'IAPLACS_SCRIPT_DIR="{scripts}"\n'
        f'iaplacs_runtime_root() {{ printf "%s\\n" "{tmp_path}"; }}\n'
    )
    (scripts / "plot_scheduler.sh").write_text("iaplacs_plot_entry() { :; }\n")
    (scripts / "upload_ningxia_download.sh").write_text(
        f'printf "%s\\n" "$1" >> "{tmp_path}/uploaded"\n'
    )
    for name, text in {
        "flock": "#!/bin/bash\nexit 0\n",
        "python": "#!/bin/bash\nexit 0\n",
        "find": "#!/bin/bash\nprintf '%s\\n' 2026112212 2026112206 2026112200 2026112118\n",
    }.items():
        target = bins / name
        target.write_text(text)
        target.chmod(0o755)
    for run in ("2026112212", "2026112206", "2026112200", "2026112118"):
        folder = tmp_path / "model" / run / "gfs/wrf"
        folder.mkdir(parents=True)
        (folder / "rsl.error.0000").write_text(
            "still running\n" if run == "2026112212" else "SUCCESS COMPLETE WRF\n"
        )
        stamp = f"{run[:4]}-{run[4:6]}-{run[6:8]}_{run[8:]}:00:00"
        (folder / f"wrfout_d01_{stamp}").touch()
    monkeypatch.setenv("PATH", f"{bins}:{os.environ['PATH']}")
    monkeypatch.setenv("PYTHON_BIN", str(bins / "python"))
    monkeypatch.setenv("NINGXIA_DOWNLOAD_MODEL_ROOT", str(tmp_path / "model"))
    subprocess.run(["bash", str(scripts / script.name), "--recent", "2"], check=True)
    assert (tmp_path / "uploaded").read_text().splitlines() == [
        "20261122_06",
        "20261122_00",
    ]
