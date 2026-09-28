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
