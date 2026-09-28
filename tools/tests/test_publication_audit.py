"""A failing publisher must not prevent checks of the other services."""

import subprocess
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
