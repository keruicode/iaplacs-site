"""Track forecast publication separately from model-file generation time."""

from __future__ import annotations

import hashlib
import json
import logging
import os
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

LOG = logging.getLogger(__name__)


def frame_assets(frame: dict) -> dict:
    """Identify published assets, ignoring volatile catalog display metadata."""
    asset = {
        key: frame[key]
        for key in (
            "id",
            "file",
            "bytes",
            "full_file",
            "full_bytes",
            "preview_file",
            "preview_bytes",
        )
        if key in frame
    }
    individual = frame.get("individual_frames", [])
    if individual:
        asset["individual_frames"] = sorted(
            (frame_assets(item) for item in individual),
            key=lambda item: (item.get("id", ""), item.get("file", "")),
        )
    return asset


def forecast_fingerprint(run: dict) -> str:
    """Hash assets, not changing summary valid_time/labels or observation data."""
    products = [
        {
            "id": item.get("id"),
            "frames": sorted(
                (frame_assets(frame) for frame in item.get("frames", [])),
                key=lambda frame: (frame.get("id", ""), frame.get("file", "")),
            ),
        }
        for item in run.get("products", [])
        if item.get("id") != "cma_observed_precip_24h"
    ]
    payload = {
        "fingerprint_version": 2,
        "generated_at": run.get("published_at"),
        "products": sorted(products, key=lambda item: item["id"] or ""),
    }
    return hashlib.sha256(
        json.dumps(payload, sort_keys=True, ensure_ascii=False).encode("utf-8")
    ).hexdigest()


def runs_by_key(catalog: dict) -> dict[tuple[str, str], dict]:
    """Index runs by service and run ID, not just the shared initialization."""
    return {
        (service_id, run["id"]): run
        for service_id, service in catalog.get("services", {}).items()
        for run in service.get("runs", [])
        if run.get("id")
    }


def historical_publications(
    root: Path, wanted: dict[tuple[str, str], str], limit: int = 200
) -> dict[tuple[str, str], str]:
    """Find the commit introducing each current asset revision, when retained."""
    relative = "data/current/forecast-runs.json"
    try:
        history = subprocess.run(
            ["git", "log", f"-{limit}", "--format=%H %ct", "--", relative],
            cwd=root,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
    except (subprocess.CalledProcessError, FileNotFoundError) as error:
        LOG.warning("Cannot inspect publication history: %s", error)
        return {}

    found: dict[tuple[str, str], str] = {}
    pending = dict(wanted)
    for line in history:
        commit, epoch = line.split()
        try:
            result = subprocess.run(
                ["git", "show", f"{commit}:{relative}"],
                cwd=root,
                check=True,
                capture_output=True,
                text=True,
            )
            past = runs_by_key(json.loads(result.stdout))
        except (subprocess.CalledProcessError, json.JSONDecodeError) as error:
            LOG.warning("Cannot read historical catalog %s: %s", commit, error)
            continue
        for key, fingerprint in list(pending.items()):
            previous = past.get(key)
            if previous and forecast_fingerprint(previous) == fingerprint:
                found[key] = datetime.fromtimestamp(
                    int(epoch), tz=timezone.utc
                ).isoformat()
            elif key in found:
                del pending[key]
        if not pending:
            break
    # Without an older different revision, the history limit is inconclusive.
    return {key: value for key, value in found.items() if key not in pending}


def stamp_publications(
    catalog: dict, previous: dict, root: Path, now: datetime | None = None
) -> None:
    """Stamp changed forecast revisions; unchanged audits keep the original time.

    The timestamp is the data-publication transaction time after asset upload,
    before its catalog commit. It is not the later GitHub Pages deployment time.
    Existing revisions without a timestamp are recovered from Git, not dated now.
    """
    timestamp = (now or datetime.now(timezone.utc)).isoformat()
    old_runs = runs_by_key(previous)
    current_runs = runs_by_key(catalog)
    missing: dict[tuple[str, str], str] = {}
    for key, run in current_runs.items():
        fingerprint = forecast_fingerprint(run)
        old = old_runs.get(key)
        run["publication_fingerprint"] = fingerprint
        if old and forecast_fingerprint(old) == fingerprint:
            if (
                old.get("publication_time")
                and old.get("publication_fingerprint") == fingerprint
            ):
                run["publication_time"] = old["publication_time"]
            else:
                run.pop("publication_time", None)
                missing[key] = fingerprint
        else:
            run["publication_time"] = timestamp
    if missing:
        for key, value in historical_publications(root, missing).items():
            current_runs[key]["publication_time"] = value


def write_catalog(path: Path, catalog: dict) -> None:
    """Replace a catalog atomically, never exposing a half-written JSON file."""
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(catalog, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        os.chmod(temporary, path.stat().st_mode & 0o777 if path.exists() else 0o644)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)
