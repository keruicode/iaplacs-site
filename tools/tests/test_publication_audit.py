"""A failing publisher must not prevent checks of the other services."""

import os
import shlex
import subprocess
import time
from pathlib import Path

import pytest

AUDITOR = Path(__file__).resolve().parents[1] / "audit_iap_forecast_publication.sh"


@pytest.mark.parametrize("status, failures", [(0, 0), (1, 1), (75, 0), (129, 1)])
def test_action_failure_does_not_abort_audit(status: int, failures: int) -> None:
    source = AUDITOR.read_text(encoding="utf-8")
    function = source.split("run_action() {", 1)[1].split("\npanel_windows()", 1)[0]
    script = (
        "set -euo pipefail\nDRY_RUN=0\nACTION_FAILURES=0\n"
        "log() { printf '%s\\n' \"$*\"; }\n"
        "run_action() {"
        + function
        + f"\nrun_action bash -c 'exit {status}'\n"
        + "run_action printf 'NEXT_SERVICE\\n'\n"
        + "printf 'FAILURES=%s\\n' \"$ACTION_FAILURES\"\n"
    )
    result = subprocess.run(
        ["bash", "-c", script], check=True, capture_output=True, text=True
    )
    assert "NEXT_SERVICE" in result.stdout
    assert f"FAILURES={failures}" in result.stdout


def test_dispatch_isolates_crash_and_slow_service(tmp_path: Path) -> None:
    source = AUDITOR.read_text(encoding="utf-8")
    function = source.split("dispatch_services() {", 1)[1].split(
        '\nif [[ "$SERVICE" == all ]]', 1
    )[0]
    child = tmp_path / AUDITOR.name
    child.write_text(
        'set -euo pipefail\ncase "$2" in\n'
        f'ningxia) touch "{tmp_path}/started"; '
        f'while [[ ! -e "{tmp_path}/release" ]]; do sleep 0.05; done; false ;;\n'
        f'*) touch "{tmp_path}/$2" ;;\nesac\n'
    )
    script = (
        "set -euo pipefail\nDRY_RUN=0\n"
        f"IAPLACS_SCRIPT_DIR={shlex.quote(str(tmp_path))}\n"
        "dispatch_services() {" + function + "\ndispatch_services\n"
    )
    process = subprocess.Popen(["bash", "-c", script])
    try:
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if all((tmp_path / name).exists() for name in ("xinjiang", "yunnan")):
                break
            time.sleep(0.05)
        assert (tmp_path / "xinjiang").exists()
        assert (tmp_path / "yunnan").exists()
        assert process.poll() is None  # Ningxia is still waiting, others finished.
    finally:
        (tmp_path / "release").touch()
        status = process.wait(timeout=5)
    assert status == 1  # Failure is reported, not silently swallowed.


def test_scoped_worker_lock_and_failure_retry(tmp_path: Path) -> None:
    """Exercise real inherited fcntl locks without requiring flock on macOS."""
    import sys

    source = AUDITOR.read_text(encoding="utf-8")
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    flock = bin_dir / "flock"
    flock.write_text(
        f"#!{sys.executable}\nimport fcntl, sys\n"
        "try: fcntl.flock(int(sys.argv[-1]), fcntl.LOCK_EX | fcntl.LOCK_NB)\n"
        "except BlockingIOError: sys.exit(1)\n"
    )
    flock.chmod(0o755)
    (tmp_path / "runtime_paths.sh").write_text(
        f'IAPLACS_SCRIPT_DIR="{tmp_path}"\n'
        'iaplacs_runtime_root() { printf "%s" "$1"; }\n'
    )
    main = '\nlog "publication audit started'
    stub = (
        '\nsubmit_missing_render() {\nif [[ "$SERVICE" == ningxia ]]; then\n'
        f'touch "{tmp_path}/started"\n'
        f'while [[ ! -e "{tmp_path}/release" ]]; do sleep 0.05; done\n'
        "false\nfi\n}\nfetch_public_catalog() { return 0; }\n"
        "list_output_runs() { :; }\n"
    )
    worker = tmp_path / AUDITOR.name
    worker.write_text(source.replace(main, stub + main, 1))
    env = dict(
        os.environ,
        PATH=f"{bin_dir}:{os.environ['PATH']}",
        PYTHON_BIN=sys.executable,
        NCDUMP_BIN="/usr/bin/true",
        LOG_DIR=str(tmp_path / "logs"),
    )
    command = ["bash", str(worker), "--service"]
    first = subprocess.Popen(command + ["ningxia"], env=env, stdout=subprocess.PIPE)
    try:
        deadline = time.monotonic() + 5
        while not (tmp_path / "started").exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        assert (tmp_path / "started").exists()
        busy = subprocess.run(
            command + ["ningxia"],
            env=env,
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        assert busy.returncode == 0
        assert "already running" in busy.stdout
        for service in ("xinjiang", "yunnan"):
            other = subprocess.run(
                command + [service],
                env=env,
                capture_output=True,
                text=True,
                timeout=5,
                check=False,
            )
            assert other.returncode == 0, other.stderr
            assert "audit exit=0" in other.stdout
    finally:
        (tmp_path / "release").touch()
        first.communicate(timeout=5)
    assert first.returncode == 1
    retry = subprocess.run(
        command + ["ningxia"],
        env=env,
        capture_output=True,
        text=True,
        timeout=5,
        check=False,
    )
    assert retry.returncode == 1
    assert "already running" not in retry.stdout
    assert "audit exit=1" in retry.stdout


def test_installer_preserves_unrelated_cron_and_is_idempotent(tmp_path: Path) -> None:
    import shutil

    root = tmp_path / "runtime"
    scripts = root / "scripts"
    scripts.mkdir(parents=True)
    tool_root = AUDITOR.parent
    for name in ("runtime_paths.sh", "install_iap_fast_publication_checks.sh"):
        shutil.copyfile(tool_root / name, scripts / name)
    (scripts / ".runtime-root").symlink_to("..")
    for name in (AUDITOR.name, "publish_workyn_yunnan_airports_if_new.sh"):
        script = scripts / name
        script.write_text("#!/bin/bash\nexit 0\n")
        script.chmod(0o755)
    cron = tmp_path / "cron"
    unrelated = "7 * * * * /other/model.sh\n"
    cron.write_text(
        unrelated
        + f"55 * * * * {scripts}/publish_worknx_ningxia_to_github.sh >> old.log\n"
        + f"*/2 * * * * {scripts}/{AUDITOR.name} >> old.log\n"
    )
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    crontab = bin_dir / "crontab"
    crontab.write_text(
        '#!/bin/bash\nif [[ "$1" == -l ]]; then cat "$TEST_CRON"; '
        'else cp "$1" "$TEST_CRON"; fi\n'
    )
    crontab.chmod(0o755)
    env = dict(os.environ, PATH=f"{bin_dir}:{os.environ['PATH']}", TEST_CRON=str(cron))
    command = ["bash", str(scripts / "install_iap_fast_publication_checks.sh")]
    subprocess.run(command, env=env, check=True, capture_output=True)
    installed = cron.read_text()
    subprocess.run(command, env=env, check=True, capture_output=True)
    assert cron.read_text() == installed
    assert unrelated in installed
    assert "55 * * * *" not in installed
    for service in ("ningxia", "xinjiang", "yunnan"):
        assert installed.count(f"--service {service}") == 1
    assert "1-59/2 * * * *" in installed
    assert list((root / "crontab_archive").glob("crontab-before-*"))


def test_publisher_cannot_consume_remaining_historical_runs() -> None:
    source = AUDITOR.read_text(encoding="utf-8")
    function = source.split("run_action() {", 1)[1].split("\npanel_windows()", 1)[0]
    script = (
        "set -euo pipefail\nDRY_RUN=0\nACTION_FAILURES=0\n"
        "log() { :; }\nrun_action() {"
        + function
        + "\nwhile read -r run; do\n"
        + "printf 'CHECK:%s\\n' \"$run\"\n"
        + "run_action bash -c 'cat >/dev/null'\n"
        + "done < <(printf 'latest\\nhistory\\n')\n"
    )
    result = subprocess.run(
        ["bash", "-c", script], check=True, capture_output=True, text=True
    )
    assert result.stdout.splitlines() == ["CHECK:latest", "CHECK:history"]


@pytest.mark.parametrize("exit_code, expected_calls", [(1, 3), (75, 1)])
def test_existing_output_retry_budget(
    tmp_path: Path, exit_code: int, expected_calls: int
) -> None:
    source = AUDITOR.read_text(encoding="utf-8")
    function = source.split("run_action() {", 1)[1].split("\npanel_windows()", 1)[0]
    counter = tmp_path / "calls"
    script = (
        "set -euo pipefail\nDRY_RUN=0\nACTION_FAILURES=0\n"
        "PUBLISH_RETRY_ATTEMPTS=3\nPUBLISH_RETRY_DELAY_SECONDS=0\n"
        "log() { :; }\n"
        f"publisher() {{ echo called >> '{counter}'; return {exit_code}; }}\n"
        "run_action() {"
        + function
        + "\nrun_action publisher --output-run 20260927_18\n"
    )
    subprocess.run(["bash", "-c", script], check=True, capture_output=True, text=True)
    assert len(counter.read_text().splitlines()) == expected_calls


def test_completed_scan_ignores_backups(tmp_path: Path) -> None:
    wrf = tmp_path / "2026093018" / "gfs" / "wrf"
    wrf.mkdir(parents=True)
    live = wrf / "wrfout_d01_2026-09-30_18:00:00"
    live.touch()
    live.with_name(live.name + "_bak").touch()
    (wrf / "rsl.error.0000").write_text("SUCCESS COMPLETE WRF\n")
    source = AUDITOR.read_text(encoding="utf-8")
    function = source.split("list_completed_wrf() {", 1)[1].split(
        "\nutc_wrf_prefix()", 1
    )[0]
    script = (
        "set -euo pipefail\nMODEL_AUDIT_RUNS=1\n"
        f"find() {{ printf '%s\\n' {shlex.quote(str(wrf.parents[1]))}; }}\n"
        "list_completed_wrf() {"
        + function
        + f"\nlist_completed_wrf {shlex.quote(str(tmp_path))}\n"
    )
    result = subprocess.run(
        ["bash", "-c", script], check=True, capture_output=True, text=True
    )
    assert result.stdout.strip() == str(live)
    live.unlink()
    result = subprocess.run(
        ["bash", "-c", script], check=False, capture_output=True, text=True
    )
    assert not result.stdout.strip()


@pytest.mark.parametrize("failure", ["prefix", "time_count"])
def test_bad_model_record_does_not_abort_later_services(failure: str) -> None:
    source = AUDITOR.read_text(encoding="utf-8")
    function = source.split("submit_missing_render() {", 1)[1].split(
        '\nlog "publication audit started', 1
    )[0]
    # macOS Bash 3 lacks uppercase expansion; only normalize log formatting.
    function = function.replace("${family^^}", "${family}")
    script = (
        "set -euo pipefail\nACTION_FAILURES=0\nMISSING_RENDER_REPAIRS=0\n"
        "log() { printf '%s\\n' \"$*\"; }\n"
        "list_completed_wrf() { printf 'broken\\ngood\\n'; }\n"
        "utc_wrf_prefix() { "
        + ('[[ "$1" != broken ]] || return 1; ' if failure == "prefix" else "")
        + "printf 20260930_18; }\n"
        "wrf_time_count() { "
        + ('[[ "$1" != broken ]] || return 1; ' if failure == "time_count" else "")
        + "printf 25; }\n"
        "expected_hourly_count() { printf 12; }\n"
        "panel_windows() { :; }\nwindow_count() { printf 0; }\n"
        "run_action() { ACTION_SUCCEEDED=1; printf 'REPAIRED\\n'; }\n"
        "submit_missing_render() {"
        + function
        + "\nsubmit_missing_render xinjiang /model /output /publisher\n"
        "printf 'NEXT_SERVICE\\n'\n"
    )
    result = subprocess.run(
        ["bash", "-c", script], check=True, capture_output=True, text=True
    )
    assert "REPAIRED" in result.stdout
    assert "NEXT_SERVICE" in result.stdout
