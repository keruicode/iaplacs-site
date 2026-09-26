import copy
import json
import os
import subprocess
from datetime import datetime, timezone

from forecast_publication import (
    forecast_fingerprint,
    historical_publications,
    stamp_publications,
    write_catalog,
)


def catalog():
    return {
        "services": {
            "ningxia": {
                "runs": [
                    {
                        "id": "20260926_00",
                        "published_at": "2026-09-26T19:16:14+08:00",
                        "products": [
                            {
                                "id": "rain",
                                "frames": [{"file": "one.webp", "bytes": 42}],
                            }
                        ],
                    }
                ]
            }
        }
    }


def first_run(data):
    return data["services"]["ningxia"]["runs"][0]


def test_new_publication_and_noop(tmp_path):
    data = catalog()
    now = datetime(2026, 9, 26, 12, 0, tzinfo=timezone.utc)
    stamp_publications(data, {}, tmp_path, now)
    assert first_run(data)["publication_time"] == now.isoformat()
    previous = copy.deepcopy(data)
    stamp_publications(data, previous, tmp_path)
    assert data == previous
    assert first_run(data)["published_at"] == "2026-09-26T19:16:14+08:00"


def test_forecast_change_gets_new_time(tmp_path):
    previous = catalog()
    first_run(previous)["publication_time"] = "2026-09-26T12:00:00+00:00"
    data = copy.deepcopy(previous)
    first_run(data)["products"][0]["frames"][0]["bytes"] = 43
    now = datetime(2026, 9, 26, 13, 0, tzinfo=timezone.utc)
    stamp_publications(data, previous, tmp_path, now)
    assert first_run(data)["publication_time"] == now.isoformat()


def test_observation_and_metrics_do_not_republish(tmp_path):
    previous = catalog()
    stamp_publications(previous, {}, tmp_path)
    data = copy.deepcopy(previous)
    first_run(data)["products"][0]["metrics"] = [{"label": "生成时间", "value": "x"}]
    first_run(data)["products"].append(
        {"id": "cma_observed_precip_24h", "frames": [{"file": "new.jpg"}]}
    )
    stamp_publications(data, previous, tmp_path)
    assert (
        first_run(data)["publication_time"] == first_run(previous)["publication_time"]
    )


def test_unknown_history_is_not_fabricated(tmp_path):
    previous = catalog()
    data = copy.deepcopy(previous)
    stamp_publications(data, previous, tmp_path)
    assert "publication_time" not in first_run(data)


def test_historical_revision_and_atomic_write(tmp_path):
    def git(*args, date=None):
        environment = os.environ.copy()
        if date:
            environment.update(GIT_AUTHOR_DATE=date, GIT_COMMITTER_DATE=date)
        return subprocess.run(
            ["git", *args],
            cwd=tmp_path,
            check=True,
            capture_output=True,
            text=True,
            env=environment,
        ).stdout.strip()

    git("init")
    git("config", "user.name", "Test")
    git("config", "user.email", "test@example.invalid")
    path = tmp_path / "data/current/forecast-runs.json"
    path.parent.mkdir(parents=True)
    old = catalog()
    first_run(old)["products"][0]["frames"][0]["bytes"] = 1
    write_catalog(path, old)
    git("add", ".")
    git("commit", "-m", "old", date="2026-09-26T19:30:00+08:00")
    current = catalog()
    write_catalog(path, current)
    git("add", ".")
    git("commit", "-m", "published", date="2026-09-26T19:37:14+08:00")
    epoch = int(git("log", "-1", "--format=%ct"))
    frame = first_run(current)["products"][0]["frames"][0]
    frame["valid_time"] = "2026-09-28T08:00:00+08:00"
    first_run(current)["publication_time"] = "2026-09-26T13:07:52+00:00"
    first_run(current)["publication_fingerprint"] = "legacy-metadata-fingerprint"
    write_catalog(path, current)
    git("add", ".")
    git("commit", "-m", "metadata only", date="2026-09-26T21:07:52+08:00")
    wanted = {("ningxia", "20260926_00"): forecast_fingerprint(first_run(current))}
    found = historical_publications(tmp_path, wanted)
    assert found == {
        ("ningxia", "20260926_00"): datetime.fromtimestamp(
            epoch, timezone.utc
        ).isoformat()
    }
    stamp_publications(current, copy.deepcopy(current), tmp_path)
    assert first_run(current)["publication_time"] == next(iter(found.values()))
    assert (
        json.loads(path.read_text())["services"]["ningxia"]["runs"][0][
            "publication_time"
        ]
        == "2026-09-26T13:07:52+00:00"
    )
    assert not list(path.parent.glob(".forecast-runs.json.*"))


def test_frame_metadata_changes_do_not_republish(tmp_path):
    previous = catalog()
    stamp_publications(previous, {}, tmp_path)
    current = copy.deepcopy(previous)
    frame = first_run(current)["products"][0]["frames"][0]
    frame.update(valid_time="2026-09-28T08:00:00+08:00", valid_label="Changed")
    stamp_publications(current, previous, tmp_path)
    assert (
        first_run(current)["publication_time"]
        == first_run(previous)["publication_time"]
    )
    without_metadata = copy.deepcopy(current)
    del first_run(without_metadata)["products"][0]["frames"][0]["valid_time"]
    stamp_publications(without_metadata, current, tmp_path)
    assert (
        first_run(without_metadata)["publication_time"]
        == first_run(previous)["publication_time"]
    )


def test_added_hourly_assets_are_a_real_publication(tmp_path):
    previous = catalog()
    stamp_publications(previous, {}, tmp_path)
    current = copy.deepcopy(previous)
    first_run(current)["products"][0]["frames"][0]["individual_frames"] = [
        {"id": "hour1", "file": "hour1.webp", "bytes": 10}
    ]
    now = datetime(2026, 9, 26, 12, 0, tzinfo=timezone.utc)
    stamp_publications(current, previous, tmp_path, now)
    assert first_run(current)["publication_time"] == now.isoformat()


def test_history_limit_does_not_claim_first_publication(tmp_path):
    assert historical_publications(tmp_path, {}) == {}
