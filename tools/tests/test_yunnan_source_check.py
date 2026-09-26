"""Exercise the shell selector without WRF data or publication side effects."""

import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

TOOLS = Path(__file__).resolve().parents[1]


def executable(path: Path, source: str) -> None:
    path.write_text(f"#!{sys.executable}\n{source}\n", encoding="utf-8")
    path.chmod(0o755)


@pytest.fixture
def selector(tmp_path: Path):
    scripts, root, state, bin_dir = (
        tmp_path / x for x in ("scripts", "WORK", "state", "bin")
    )
    for path in (scripts, root, state, bin_dir):
        path.mkdir()
    for name in ("runtime_paths.sh", "publish_workyn_yunnan_airports_if_new.sh"):
        shutil.copy2(TOOLS / name, scripts / name)
    executable(bin_dir / "flock", "raise SystemExit(0)")
    executable(
        bin_dir / "find",
        "import sys\nfrom pathlib import Path\n"
        "for path in Path(sys.argv[1]).rglob('wrfout_d01_*'): print(path)",
    )
    executable(
        bin_dir / "stat",
        "import sys\nfrom pathlib import Path\n"
        "path = Path(sys.argv[-1])\n"
        "print(path.with_suffix('.bytes').read_text() if sys.argv[2] == '%s' else '100')",
    )
    executable(
        bin_dir / "ncdump",
        "import sys\nfrom pathlib import Path\n"
        "count = Path(sys.argv[-1]).with_suffix('.times').read_text()\n"
        "print(f'Time = UNLIMITED ; // ({count} currently)')",
    )
    executable(
        bin_dir / "publisher", "raise RuntimeError('Must not publish during dry run')"
    )
    env = dict(os.environ)
    env.update(
        PATH=f"{bin_dir}:{env['PATH']}",
        WORK_YN_ROOT=str(root),
        STATE_DIR=str(state),
        LAST_PREFIX_FILE=str(state / "signature"),
        PUBLISHER=str(bin_dir / "publisher"),
        NCDUMP_BIN=str(bin_dir / "ncdump"),
    )
    for key in ("MIN_WRFOUT_BYTES", "MIN_TIME_COUNT"):
        env.pop(key, None)
    return scripts, root, env


def add_run(root: Path, day: str, complete: bool, count: int, size: int) -> None:
    directory = root / f"202609{day}00/gfs/wrf"
    directory.mkdir(parents=True)
    path = directory / f"wrfout_d01_2026-09-{day}_00:00:00"
    path.write_bytes(b"fixture")
    path.with_suffix(".bytes").write_text(str(size), encoding="utf-8")
    path.with_suffix(".times").write_text(str(count), encoding="utf-8")
    (directory / "rsl.error.0000").write_text(
        "SUCCESS COMPLETE WRF" if complete else "Timing for main", encoding="utf-8"
    )


@pytest.mark.parametrize(
    "complete,count,size,expected",
    [
        (True, 25, 14_000_000_000, "20260926_00"),
        (True, 14, 1_000_000, "20260926_00"),
        (False, 25, 14_000_000_000, "20260925_00"),
        (True, 13, 14_000_000_000, "20260925_00"),
        (True, 25, 0, "20260925_00"),
    ],
)
def test_select_completed_run(selector, complete, count, size, expected):
    scripts, root, env = selector
    add_run(root, "25", True, 37, 30_000_000_000)
    add_run(root, "26", complete, count, size)
    result = subprocess.run(
        [
            "bash",
            str(scripts / "publish_workyn_yunnan_airports_if_new.sh"),
            "--dry-run",
        ],
        env=env,
        capture_output=True,
        text=True,
        check=True,
    )
    assert f"Would publish Yunnan airport run {expected};" in result.stdout
    assert not Path(env["LAST_PREFIX_FILE"]).exists()


@pytest.mark.parametrize("threshold", ["-1", "invalid"])
def test_invalid_size_threshold(selector, threshold):
    scripts, _, env = selector
    env["MIN_WRFOUT_BYTES"] = threshold
    result = subprocess.run(
        [
            "bash",
            str(scripts / "publish_workyn_yunnan_airports_if_new.sh"),
            "--dry-run",
        ],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 64
    assert "positive integer" in result.stderr
