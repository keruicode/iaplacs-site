"""Exercise recovery in disposable repositories, never production data."""

import json
import subprocess
from pathlib import Path

import pytest

# isort: split
import publication_checkout as checkout


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    remote = tmp_path / "remote.git"
    subprocess.run(
        ["git", "init", "--bare", str(remote)], check=True, capture_output=True
    )
    root = tmp_path / "publisher"
    root.mkdir()
    checkout.git(root, "init")
    checkout.git(root, "symbolic-ref", "HEAD", "refs/heads/main")
    checkout.git(root, "config", "user.name", "Test Publisher")
    checkout.git(root, "config", "user.email", "publisher@example.invalid")
    for relative in checkout.CATALOGS:
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(' {"original": true}\n\n', encoding="utf-8")
    (root / "script.sh").write_text("original\n", encoding="utf-8")
    checkout.git(root, "add", ".")
    checkout.git(root, "commit", "-m", "Initial fixture")
    checkout.git(root, "remote", "add", "origin", str(remote))
    checkout.git(root, "push", "-u", "origin", "main")
    return root


def test_owned_partial_catalog_is_backed_up_and_recovered(repo: Path) -> None:
    original = (repo / checkout.CATALOGS[0]).read_bytes()
    checkout.prepare(repo)
    path = repo / checkout.CATALOGS[0]
    path.write_bytes(b'{"partial":')
    checkout.git(repo, "add", checkout.CATALOGS[0])
    checkout.recover(repo)
    assert path.read_bytes() == original
    assert not checkout.changed_paths(repo)
    backups = list(checkout.state_directory(repo).glob("interrupted-*"))
    assert len(backups) == 1
    assert (backups[0] / path.name).read_bytes() == b'{"partial":'
    assert (backups[0] / "index.patch").stat().st_size > 0


def test_unowned_catalog_changes_are_not_discarded(repo: Path) -> None:
    path = repo / checkout.CATALOGS[0]
    path.write_text('{"manual": true}', encoding="utf-8")
    with pytest.raises(RuntimeError, match="Unowned"):
        checkout.prepare(repo)
    assert json.loads(path.read_text()) == {"manual": True}


def test_unexpected_code_changes_stop_recovery(repo: Path) -> None:
    checkout.prepare(repo)
    (repo / "script.sh").write_text("manual edit\n", encoding="utf-8")
    with pytest.raises(RuntimeError, match="outside owned"):
        checkout.recover(repo)
    assert (repo / "script.sh").read_text() == "manual edit\n"


def test_committed_but_unpushed_output_is_retried(repo: Path) -> None:
    checkout.prepare(repo)
    (repo / checkout.CATALOGS[0]).write_text('{"complete": true}\n', encoding="utf-8")
    checkout.git(repo, "add", checkout.CATALOGS[0])
    checkout.git(repo, "commit", "-m", "Generated output")
    commit = checkout.git(repo, "rev-parse", "HEAD")
    assert checkout.git(repo, "rev-parse", "origin/main") != commit
    checkout.prepare(repo)
    assert checkout.git(repo, "rev-parse", "origin/main") == commit
    checkout.finish(repo)
    assert not (checkout.state_directory(repo) / "active.json").exists()


def test_changed_head_with_dirty_files_requires_review(repo: Path) -> None:
    checkout.prepare(repo)
    checkout.git(repo, "commit", "--allow-empty", "-m", "External commit")
    (repo / checkout.CATALOGS[0]).write_text("{}\n", encoding="utf-8")
    with pytest.raises(RuntimeError, match="outside owned"):
        checkout.recover(repo)


@pytest.mark.parametrize("failures", [1, 2, 3])
def test_transient_push_errors_retry_with_backoff(monkeypatch, failures: int) -> None:
    pushes = []
    sleeps = []

    def fake_git(root, *args):
        if args[0] == "push":
            pushes.append(args)
            if len(pushes) <= failures:
                raise subprocess.CalledProcessError(128, args, stderr="network failure")
        return ""

    monkeypatch.setattr(checkout, "git", fake_git)
    monkeypatch.setattr(checkout.time, "sleep", sleeps.append)
    if failures == 3:
        with pytest.raises(subprocess.CalledProcessError):
            checkout.network_sync(Path("."), push=True)
    else:
        checkout.network_sync(Path("."), push=True)
    assert len(pushes) == min(failures + 1, 3)
    assert sleeps == [10, 20][: min(failures, 2)]


def test_failed_finish_retains_recovery_marker(repo: Path, monkeypatch) -> None:
    checkout.prepare(repo)

    def fail(*args, **kwargs):
        raise subprocess.TimeoutExpired("git push", 90)

    monkeypatch.setattr(checkout, "network_sync", fail)
    with pytest.raises(subprocess.TimeoutExpired):
        checkout.finish(repo)
    assert (checkout.state_directory(repo) / "active.json").is_file()
