"""Ensure moving scripts never moves forecast outputs or assets."""

import shutil
import subprocess
from pathlib import Path

import pytest

TOOLS = Path(__file__).resolve().parents[1]


@pytest.fixture
def runtime(tmp_path):
    scripts = tmp_path / "scripts"
    scripts.mkdir()
    (scripts / ".runtime-root").symlink_to("..")
    shutil.copy2(TOOLS / "runtime_paths.sh", scripts)
    return tmp_path, scripts


def test_separate_script_and_data_roots(runtime):
    root, scripts = runtime
    command = (
        'source "$1/runtime_paths.sh"; '
        'iaplacs_runtime_root "$1"; iaplacs_script_root "$2"; '
        'printf "%s\\n" "$IAPLACS_SCRIPT_DIR"'
    )
    output = subprocess.check_output(
        ["bash", "-c", command, "bash", str(scripts), str(root)], text=True
    ).splitlines()
    assert output == [str(root), str(scripts), str(scripts)]


@pytest.mark.parametrize(
    "name,variables,expected",
    [
        (
            "render_worknx_ningxia_overview.sh",
            ["OUTPUT_ROOT", "NCL_SCRIPT", "AVIATION_RENDERER"],
            [
                "worknx_ningxia_overview",
                "scripts/rain_worknx_ningxia_hour_bjt.ncl",
                "scripts/render_yunnan_airport_aviation_preview.py",
            ],
        ),
        (
            "render_worknx_yunnan_airports_overview.sh",
            ["OUTPUT_ROOT", "NCL_SCRIPT", "POINT_SCRIPT"],
            [
                "worknx_yunnan_airports_overview",
                "scripts/rain_worknx_yunnan_airport_hour_bjt.ncl",
                "scripts/extract_yunnan_airport_precip.py",
            ],
        ),
        (
            "publish_worknx_ningxia_to_github.sh",
            ["OUTPUT_ROOT", "RENDERER", "PUBLISHER"],
            [
                "worknx_ningxia_overview",
                "scripts/render_worknx_ningxia_overview.sh",
                "scripts/publish_worknx_summary_to_github.sh",
            ],
        ),
    ],
)
def test_real_entry_defaults(runtime, name, variables, expected):
    root, scripts = runtime
    prefix = (TOOLS / name).read_text(encoding="utf-8").split("usage()", 1)[0]
    probe = scripts / "probe.sh"
    probe.write_text(
        prefix
        + '\nprintf "%s\\n" '
        + " ".join(f'"${{{key}}}"' for key in variables)
        + "\n",
        encoding="utf-8",
    )
    output = subprocess.check_output(["bash", str(probe)], text=True).splitlines()
    assert output == [str(root / value) for value in expected]


def test_flat_legacy_layout(tmp_path):
    shutil.copy2(TOOLS / "runtime_paths.sh", tmp_path)
    output = subprocess.check_output(
        [
            "bash",
            "-c",
            'source "$1/runtime_paths.sh"; iaplacs_runtime_root "$1"; iaplacs_script_root "$1"',
            "bash",
            str(tmp_path),
        ],
        text=True,
    ).splitlines()
    assert output == [str(tmp_path), str(tmp_path)]
