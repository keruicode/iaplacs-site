"""Latest-run priority and retry receipts must survive partial publication."""

import json
import os
import shlex
import subprocess
import sys
from pathlib import Path

import pytest

TOOLS = Path(__file__).resolve().parents[1]


@pytest.mark.parametrize(
    "service,prefix", [("ningxia", ""), ("yunnan", "airport_yunnan_"), ("xinjiang", "")]
)
@pytest.mark.parametrize("present", [True, False])
def test_priority_selects_catalog_latest(tmp_path, service, prefix, present):
    source = (TOOLS / "audit_iap_forecast_publication.sh").read_text()
    function = source.split("prioritize_latest_visibility() {", 1)[1].split(
        "\npublic_windows()", 1
    )[0]
    key = "airport" if service == "yunnan" else service
    catalog = tmp_path / "catalog.json"
    catalog.write_text(
        json.dumps(
            {
                "services": {
                    key: {
                        "latest_run": prefix + "20261031_18",
                        "runs": [
                            {"id": prefix + "20261030_00"},
                            {"id": prefix + "20261031_18"},
                        ],
                    }
                }
            }
        )
    )
    script = (
        "set -euo pipefail\n"
        f"SERVICE={service}\nPYTHON_BIN={shlex.quote(sys.executable)}\n"
        f"AUDIT_CATALOG={shlex.quote(str(catalog))}\nIAPLACS_SCRIPT_DIR=/scripts\n"
        f"public_product_exists() {{ return {0 if present else 1}; }}\n"
        "log() { :; }\nrun_action() { printf '%s\\n' \"$*\"; }\n"
        "prioritize_latest_visibility() {"
        + function
        + "\nprioritize_latest_visibility\n"
    )
    result = subprocess.run(
        ["bash", "-c", script], check=True, capture_output=True, text=True
    )
    assert f"--profile {service} --run 20261031_18" in result.stdout
    assert "20261030_00" not in result.stdout
    assert ("--ensure-public" in result.stdout) is not present


def publication_fixture(tmp_path):
    scripts = tmp_path / "scripts"
    scripts.mkdir()
    (scripts / "runtime_paths.sh").write_text(
        f"IAPLACS_SCRIPT_DIR={shlex.quote(str(scripts))}\n"
        f"iaplacs_runtime_root() {{ printf '%s' {shlex.quote(str(tmp_path))}; }}\n"
    )
    publisher = scripts / "publish_work_visibility.sh"
    publisher.write_text((TOOLS / publisher.name).read_text())
    (scripts / "visibility_source.py").write_text(
        "def select_source(path, profile): return (path, 'native')\n"
    )
    (scripts / "render_work_visibility.py").write_text(
        "import pathlib,sys\np=pathlib.Path(sys.argv[sys.argv.index('--output')+1])\n"
        "p.mkdir(parents=True,exist_ok=True)\n"
        "(p/'production_manifest.json').write_text('{}')\n"
    )
    upload = scripts / "publish_airport_aviation_to_oss.sh"
    upload.write_text('#!/bin/bash\nexit "${UPLOAD_STATUS:-0}"\n')
    upload.chmod(0o755)
    wrf = tmp_path / "model/2026103118/gfs/wrf"
    wrf.mkdir(parents=True)
    (wrf / "rsl.error.0000").write_text("SUCCESS COMPLETE WRF\n")
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    flock = bin_dir / "flock"
    flock.write_text(
        f"#!{sys.executable}\nimport fcntl,sys\n"
        "try: fcntl.flock(int(sys.argv[-1]),fcntl.LOCK_EX|fcntl.LOCK_NB)\n"
        "except BlockingIOError: sys.exit(1)\n"
    )
    flock.chmod(0o755)
    sha = bin_dir / "sha256sum"
    sha.write_text(
        f"#!{sys.executable}\nimport hashlib,sys\nprint(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())\n"
    )
    sha.chmod(0o755)
    env = dict(
        os.environ,
        PATH=f"{bin_dir}:{os.environ['PATH']}",
        PYTHON_BIN=sys.executable,
        WORK_VISIBILITY_MODEL_ROOT=str(tmp_path / "model"),
    )
    return publisher, env


@pytest.mark.parametrize("status", [1, 75, 143])
def test_upload_failure_never_records_success_and_retries(tmp_path, status):
    publisher, env = publication_fixture(tmp_path)
    command = ["bash", str(publisher), "--run", "20261031_18"]
    result = subprocess.run(
        command,
        env=dict(env, UPLOAD_STATUS=str(status)),
        check=False,
        capture_output=True,
        text=True,
    )
    assert result.returncode == status
    root = tmp_path / "worknx_ningxia_overview"
    receipt = root / "20261031_18/visibility/.published-sha256"
    state = root / ".visibility-20261031_18.state"
    assert not receipt.exists()
    assert f"\tfailed_uploading_catalog\t{status}" in state.read_text()
    subprocess.run(command, env=env, check=True, capture_output=True)
    assert receipt.exists()
    assert "\tpublished\t0" in state.read_text()


def test_incomplete_model_records_waiting_not_published(tmp_path):
    publisher, env = publication_fixture(tmp_path)
    (tmp_path / "model/2026103118/gfs/wrf/rsl.error.0000").write_text("running\n")
    subprocess.run(
        ["bash", str(publisher), "--run", "20261031_18"],
        env=env,
        check=True,
        capture_output=True,
    )
    root = tmp_path / "worknx_ningxia_overview"
    assert "\twaiting_model\t0" in (root / ".visibility-20261031_18.state").read_text()
    assert not (root / "20261031_18").exists()


def test_terminated_publisher_records_nonzero_status(tmp_path):
    publisher, env = publication_fixture(tmp_path)
    (publisher.parent / "publish_airport_aviation_to_oss.sh").write_text(
        '#!/bin/bash\nkill -TERM "$PPID"\nexit 0\n'
    )
    result = subprocess.run(
        ["bash", str(publisher), "--run", "20261031_18"],
        env=env,
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    assert result.returncode == 143
    root = tmp_path / "worknx_ningxia_overview"
    assert (
        "\tfailed_uploading_catalog\t143"
        in (root / ".visibility-20261031_18.state").read_text()
    )
    assert not (root / "20261031_18/visibility/.published-sha256").exists()
