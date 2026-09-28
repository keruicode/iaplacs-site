# server02 GitHub Publishing

`server02` publishes IAP-LACS catalog updates to `keruicode/iaplacs-site`.

> 本文只记录 `server02` 的 Git/Deploy Key 环境。整站数据流、OSS、计算服务器、
> cron 与恢复操作见 [网站运行与运维总手册](网站运行与运维总手册.md)。

## Deploy Key

- Canonical private key: `~/.iaplacs/ssh-state/id_ed25519_iaplacs_github`
- Compatibility copy and SSH wrapper: `~/.ssh/id_ed25519_iaplacs_github`,
  `~/.ssh/git-iaplacs-ssh`
- The matching public key is a repository Deploy Key with write access.
- IAP publisher scripts pass the canonical key path outside `.ssh`.

## SSH Reset Recovery

The IAP and `server02` processes share the same home directory. Some account
key-download/login workflows can recreate `~/.ssh`; that removes private keys
used by automation even though the public `.pub` files are not themselves the
secret. IAP-LACS therefore keeps automation-only key copies in
`~/.iaplacs/ssh-state/` (directory mode `0700`, private-key mode `0600`).

`ensure_iaplacs_ssh_state.sh` restores the missing IAP-to-server02 `id_rsa`
and rewrites the dedicated GitHub key/wrapper. It also retains one explicitly
managed inbound public-key line, identified by the comment
`2602005529@qq.com`, in `~/.iaplacs/ssh-state/authorized_keys.iaplacs`.
When `~/.ssh` is recreated, the script appends that exact line only when it is
missing. It never removes, replaces, or otherwise changes the remaining
`authorized_keys` entries managed by the platform or user.

The user crontab runs this recovery once per hour:

```cron
0 * * * * /data1/elpt_2022_00083/kerui/Website/scripts/ensure_iaplacs_ssh_state.sh >> /data1/elpt_2022_00083/kerui/Website/logs/ssh-state-recovery.log 2>&1
```

Run the following after a `.ssh` reset, or to verify the state immediately:

```bash
/data1/elpt_2022_00083/kerui/Website/scripts/ensure_iaplacs_ssh_state.sh
```

## Git 1.8 Runtime Issue

The server's Intel environment can set an incompatible `LD_LIBRARY_PATH`, which
prevents `/usr/bin/git` and `/usr/bin/ssh-keygen` from loading. Run Git commands
with:

```bash
env -u LD_LIBRARY_PATH -u LD_PRELOAD GIT_SSH="$HOME/.ssh/git-iaplacs-ssh" /usr/bin/git <command>
```

The old Git version uses `GIT_SSH`; it does not support `GIT_SSH_COMMAND`.

## Verification

### Interrupted Catalog Publication

An interrupted SSH session can leave `data/current/manifest.json` and
`data/current/forecast-runs.json` modified before their commit. Later publishers
then fail at `git pull --rebase` with `You have unstaged changes`. This is a
shared checkout failure, not evidence that the model is incomplete or that the
GitHub key has expired. On 2026-09-28 it blocked Yunnan and Xinjiang updates.

Inspect the checkout on **server02**, under the shared publication lock:

```bash
unset LD_LIBRARY_PATH LIBRARY_PATH LD_PRELOAD
cd "$HOME/iaplacs-site"
exec 9>"$HOME/.iaplacs-github-publish.lock"
flock -w 180 9
/usr/bin/git status --short -uno
/usr/bin/git diff --stat
/usr/bin/git diff -- data/current/manifest.json data/current/forecast-runs.json
```

Keep that shell open only during maintenance; `exit` releases the lock. Before
repairing, back up both JSON files, the worktree/index patches and HEAD to a
private directory outside the checkout. Validate the JSON and verify any new
image URLs in OSS. If the only changes are confirmed generated catalog updates,
commit those two explicit paths, pull with rebase and push. Do not use
`git reset --hard`, blindly stash user changes, or add the entire image tree.
Unexpected code changes require review before proceeding.

After recovery, the two-minute audit republishes complete, already-rendered
runs. Its repair actions now log errors and continue to later services, while
returning a failing overall exit status if any action failed. This avoids
starving Xinjiang/Yunnan after a Ningxia error; it does **not** automatically
commit or discard an unknown dirty checkout. Confirm the public catalog and OSS
assets, not just the presence of local PNGs. Runs without `SUCCESS COMPLETE WRF`
must not be treated as complete.

Publisher subprocesses also receive `/dev/null` as stdin. Without this boundary,
an SSH setup command can consume the remaining run IDs from an audit's
`while read` loop, silently skipping historical runs. Heredocs inside the
publishers remain functional. A regression test explicitly checks that both the
latest and the following historical run are visited even if a child reads stdin.

### Automatic Retry and Owned Transactions

The active summary, Yunnan, hourly, aviation and CMA publishers call
`tools/publication_checkout.py prepare/finish` on server02 while holding the
existing shared lock (inherited descriptor 8). Python 3.11 is available there.
The helper refuses to run without the correct lock; it does not submit WRF jobs.

- Git pull/push uses up to three attempts, with 10-second then 20-second delays
  and a 90-second timeout per Git command. Before a new publication, it also
  pushes any previously committed but unpushed output.
- Before generated metadata changes, a clean-start transaction records HEAD and
  the exact two catalog paths in `.git/iaplacs-publication/active.json`.
- If interrupted before commit, the next publisher preserves the partial JSON,
  both Git patches and the transaction record in an `interrupted-*` directory
  alongside that marker. It restores only the two generated catalog files to
  the recorded, unchanged HEAD, then regenerates them through normal publishing.
- Recovery refuses changes to other tracked files, a changed HEAD with dirty
  files, symlinked catalogs, or dirty files without an ownership marker. These
  require manual review. Never edit catalogs manually while a publication
  transaction is open. Recovery backups are private and are not pushed to GitHub.
- Once the commit is pushed, `finish` removes the marker. Even a no-change
  publication executes `finish`, so interrupted pushes can still complete.
- The audit retries `--output-run` transmission up to three times, waiting
  15 then 30 seconds. Configure via `PUBLISH_RETRY_ATTEMPTS` (1-5) and
  `PUBLISH_RETRY_DELAY_SECONDS`. It does not immediately repeat full rendering.
  If attempts fail, it records failure and continues other services; subsequent
  two-minute checks revisit missing retained runs, without a lifetime retry cap.
- Lock contention (exit 75) is deferred without retries. A busy or failed render
  no longer counts as a successful repair that would postpone all public checks.

These retries apply to forecast publication, not to failed model jobs. CMA
observation fetching retains its existing schedule; its Git transaction gets
the same network retries and interrupted-catalog protection. A persistent
permission, disk, conflict or unknown-change error still needs intervention.

Tests exercise partial staged JSON recovery, manual-change protection,
uncommitted/committed interruptions, retry exhaustion, network backoff, busy
locks and history-loop stdin isolation in temporary local repositories. Do not
simulate a failure by corrupting the production catalog or killing live WRF jobs.

### Connectivity Checks

```bash
ssh -i ~/.ssh/id_ed25519_iaplacs_github -o IdentitiesOnly=yes -T git@github.com
cd ~/iaplacs-site
env -u LD_LIBRARY_PATH -u LD_PRELOAD GIT_SSH="$HOME/.ssh/git-iaplacs-ssh" /usr/bin/git pull --rebase origin main
env -u LD_LIBRARY_PATH -u LD_PRELOAD GIT_SSH="$HOME/.ssh/git-iaplacs-ssh" /usr/bin/git push --dry-run origin HEAD:main
```
