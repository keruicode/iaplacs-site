"""Exercise production batch upload without network credentials."""

import os
import subprocess
import sys
from pathlib import Path

import pytest
from PIL import Image


@pytest.mark.parametrize("fail", [False, True])
def test_serial_batch(tmp_path, fail):
    source = (
        Path(__file__).parents[1] / "publish_airport_aviation_to_oss.sh"
    ).read_text()
    block = source.split("upload_started=$SECONDS\n", 1)[1].split(
        'echo "OSS upload seconds=', 1
    )[0]
    destination = tmp_path / "data/current/maps/sample/supercooled"
    destination.mkdir(parents=True)
    (destination / "map.png").touch()
    capture = tmp_path / "calls"
    mock = tmp_path / "ossutil"
    mock.write_text(
        '#!/bin/bash\nprintf "%s\\n" "CALL:$GOMAXPROCS" "$@" >> "$CAPTURE"\n'
        'exit "${FAIL:-0}"\n'
    )
    mock.chmod(0o700)
    env = {
        **os.environ,
        "SITE_REPO": str(tmp_path),
        "AVIATION_DEST": str(destination),
        "ASSET_SUBDIR": "supercooled",
        "PREFIX": "iaplacs",
        "OSSUTIL_BIN": str(mock),
        "IAPLACS_OSS_BUCKET": "test-bucket",
        "IAPLACS_OSS_ENDPOINT": "test-endpoint",
        "CAPTURE": str(capture),
        "FAIL": "7" if fail else "0",
    }
    result = subprocess.run(
        ["bash", "-c", "set -Eeuo pipefail\n" + block],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    lines = capture.read_text().splitlines()
    assert lines.count("CALL:1") == (1 if fail else 2)
    assert result.returncode == (7 if fail else 0)
    assert lines[lines.index("-j") + 1] == "1"
    assert lines[lines.index("--parallel") + 1] == "1"
    assert "--disable-ignore-error" in lines
    assert lines[lines.index("--exclude") + 1] == "*"
    assert lines[lines.index("--include") + 1] == "*.png"
    assert "oss://test-bucket/iaplacs/data/current/maps/sample/supercooled/" in lines
    if not fail:
        assert "*.webp" in lines
        assert "Cache-Control:no-cache#Content-Type:image/webp" in lines


def test_conversion_preserves_bytes_and_mtime(tmp_path):
    script = Path(__file__).parents[1] / "publish_airport_aviation_to_oss.sh"
    code = script.read_text().split("<<'PY'\n", 1)[1].split("\nPY\n", 1)[0]
    for name in ["a", "b"]:
        source = tmp_path / f"{name}.png"
        with Image.new("RGB", (50, 30), (20, 70, 120)) as image:
            image.save(source)
        with Image.open(source) as original:
            image = original.convert("RGB")
            image.thumbnail((6000, 6000), Image.Resampling.LANCZOS)
            image.save(tmp_path / f"{name}.expected", "WEBP", quality=95, method=6)
            image.close()
    subprocess.run([sys.executable, "-c", code, str(tmp_path)], check=True)
    for source in tmp_path.glob("*.png"):
        output = source.with_suffix(".webp")
        assert output.read_bytes() == source.with_suffix(".expected").read_bytes()
        assert output.stat().st_mtime_ns == source.stat().st_mtime_ns
    assert not list(tmp_path.glob("*.tmp"))
