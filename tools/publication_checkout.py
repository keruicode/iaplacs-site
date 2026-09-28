"""Recover owned catalog transactions and retry Git under the publisher lock."""

from __future__ import annotations

import argparse
import fcntl
import json
import logging
import os
import subprocess
import tempfile
import time
from pathlib import Path

LOG = logging.getLogger(__name__)
CATALOGS = ("data/current/manifest.json", "data/current/forecast-runs.json")


def git(root: Path, *args: str, strip_output: bool = True) -> str:
    output = subprocess.run(
        ["git", *args],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
        timeout=90,
    ).stdout
    return output.strip() if strip_output else output


def atomic_write(path: Path, data: bytes) -> None:
    descriptor, name = tempfile.mkstemp(prefix=".publication-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def changed_paths(root: Path) -> set[str]:
    paths = set()
    for args in (("diff", "--name-only"), ("diff", "--cached", "--name-only")):
        paths.update(git(root, *args).splitlines())
    return paths


def state_directory(root: Path) -> Path:
    directory = root / git(root, "rev-parse", "--git-dir") / "iaplacs-publication"
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    return directory


def recover(root: Path) -> None:
    """Recover only a clean-start, unchanged-HEAD transaction's generated JSON."""
    state = state_directory(root)
    marker = state / "active.json"
    changed = changed_paths(root)
    if not marker.exists():
        if changed:
            raise RuntimeError(
                f"Unowned checkout changes; manual review required: {changed}"
            )
        return
    with marker.open(encoding="utf-8") as stream:
        record = json.load(stream)
    if record.get("version") != 1 or record.get("catalogs") != list(CATALOGS):
        raise RuntimeError(
            "Unknown publication transaction format; manual review required"
        )
    if not changed:
        marker.unlink()
        return
    if changed - set(CATALOGS) or git(root, "rev-parse", "HEAD") != record["head"]:
        raise RuntimeError(f"Checkout changed outside owned transaction: {changed}")
    if any((root / path).is_symlink() for path in CATALOGS):
        raise RuntimeError("Catalog path is a symlink; refusing recovery")

    backup = Path(tempfile.mkdtemp(prefix="interrupted-", dir=state))
    atomic_write(backup / "transaction.json", marker.read_bytes())
    for label, args in (
        ("worktree", ("diff", "--binary")),
        ("index", ("diff", "--cached", "--binary")),
    ):
        atomic_write(
            backup / f"{label}.patch", git(root, *args, strip_output=False).encode()
        )
    for relative in CATALOGS:
        path = root / relative
        if path.exists():
            atomic_write(backup / path.name, path.read_bytes())
    # The marker was created with a clean index under the shared lock. Keep the
    # interrupted output above, then restore only these generated catalog files.
    for relative in sorted(changed):
        baseline = git(root, "show", f"HEAD:{relative}", strip_output=False)
        json.loads(baseline)
        atomic_write(root / relative, baseline.encode())
    git(root, "reset", "-q", "HEAD", "--", *CATALOGS)
    if changed_paths(root):
        raise RuntimeError("Catalog recovery did not restore a clean checkout")
    marker.unlink()
    LOG.warning("Recovered interrupted catalog transaction; backup=%s", backup)


def network_sync(root: Path, push: bool, attempts: int = 3) -> None:
    """Retry pull/push together so a concurrent upstream commit can be rebased."""
    if attempts < 1 or attempts > 5:
        raise ValueError("attempts must be between 1 and 5")
    for attempt in range(1, attempts + 1):
        try:
            LOG.info("Git synchronization attempt %s/%s", attempt, attempts)
            git(root, "pull", "--rebase")
            if push:
                git(root, "push", "origin", "HEAD:main")
            return
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            LOG.error(
                "Git synchronization failed: %s",
                getattr(error, "stderr", None) or error,
            )
            if attempt == attempts:
                raise
            time.sleep(10 * attempt)


def prepare(root: Path) -> None:
    recover(root)
    # Also retry a previously committed but unpushed transaction, even if the
    # current publisher subsequently finds no new catalog changes.
    network_sync(root, push=True)
    if changed_paths(root):
        raise RuntimeError("Checkout must be clean before starting publication")
    for path in CATALOGS:
        json.loads(git(root, "show", f"HEAD:{path}"))
    record = {
        "version": 1,
        "head": git(root, "rev-parse", "HEAD"),
        "catalogs": list(CATALOGS),
        "started_at": time.time(),
    }
    atomic_write(state_directory(root) / "active.json", json.dumps(record).encode())


def finish(root: Path) -> None:
    if changed_paths(root):
        raise RuntimeError(
            "Uncommitted output remains; preserve transaction for recovery"
        )
    network_sync(root, push=True)
    (state_directory(root) / "active.json").unlink(missing_ok=True)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("prepare", "finish"))
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--lock-fd", type=int, default=8)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s"
    )
    try:
        lock = Path.home() / ".iaplacs-github-publish.lock"
        descriptor = os.fstat(args.lock_fd)
        expected = lock.stat()
        if (descriptor.st_dev, descriptor.st_ino) != (expected.st_dev, expected.st_ino):
            raise RuntimeError("Expected inherited shared publisher lock")
        fcntl.flock(args.lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        {"prepare": prepare, "finish": finish}[args.action](args.repo.resolve())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        LOG.error("Publication checkout stopped safely: %s", error)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
