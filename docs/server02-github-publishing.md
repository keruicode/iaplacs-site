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

### Completed-Run Discovery and Backup Files

On 2026-10-01, the two-minute audit exited before reaching Xinjiang because
the preceding WORK scan selected a `wrfout_d01_*_bak` file. The permissive glob
and reverse sort preferred the backup; UTC run parsing rejected its suffix,
and `set -e` terminated the audit. The cron schedule itself was active.

Discovery now constructs the exact initial WRF filename from the ten-digit
run directory. Backup suffixes cannot shadow the live output. Invalid run
names and unreadable NetCDF headers are logged and skipped so later model
outputs and services can still be checked. An unreadable header contributes
to the audit failure count, permitting later scheduled retries. Model files
and the WRF completion requirement are unchanged.

### Independent Service Checks (2026-10-01)

The audit now accepts `--service ningxia`, `--service xinjiang`, or
`--service yunnan`. The installer schedules each independently every two minutes,
with separate `logs/publication-audit-SERVICE.log` and `.lock` files. The default
manual command starts three separate worker processes, then waits for all and
returns failure if any failed. An unexpected shell error or a long render in one
worker cannot stop another worker from starting. An active service skips its
own overlapping checks; it does not hold a global audit lock. Existing render
locks and the server02 shared Git lock are retained.

New completed-run discovery takes place before fetching the public catalog, so
a catalog HTTP failure cannot prevent discovery/rendering of new data. An EXIT
record includes service, exit status and total elapsed seconds. Each repair
records its duration, and the shared Ningxia/Xinjiang publisher separately logs
`stage=render` and `stage=publish`. Failed actions remain eligible on the next
scheduled check. There is no automatic WRF restart or deletion of model files.

`tools/install_iap_fast_publication_checks.sh` backs up the current user's cron
before installation. It replaces only managed audit/Yunnan checks and removes
the exact old `55 * * * * .../publish_worknx_ningxia_to_github.sh` entry. That
entry unconditionally redrew and force-uploaded the latest run every hour,
including unchanged products (the Oct 1 14:55 cycle ended at 15:12:07). The
two-minute completeness audit replaces it. The independent Yunnan source-change
checker, BJT06 snapshot job, backups, observations, SSH recovery and retention
remain unchanged. Never modify server02 model-launch cron for this change.

Historical evidence distinguishes several problems, rather than attributing
all latency to one file:

- Sep 28 had an interrupted shared Git transaction; owned recovery and retry
  were added then. The cause of the original interruption is still unknown.
- Sep 29 05:10:06-05:25:15: a Ningxia repair held the global audit lock; every
  intervening two-minute check logged `already running; skip`. Similar blocking
  appears at 12:10-12:24 and during Xinjiang repairs. Scoped locks remove this
  cross-service wait, including waits caused by historical repairs.
- Sep 30/Oct 1: backup selection aborted discovery before Xinjiang. The hourly
  Ningxia redraw briefly changed control flow, explaining the observed xx:56
  Xinjiang starts. Exact-name discovery fixes that failure independently.
- Xinjiang run 20260930_00: WRF ended Sep 30 19:15:53 BJT; render action started
  19:56:06; catalog publication was 20:15:14. Run 20260930_12: Oct 1 06:54:59,
  07:56:07, 08:14:24 respectively. Thus waiting before rendering was 40/61
  minutes, while rendering plus publication added about 19/18 minutes.

Two-minute detection does not promise two-minute delivery. Rendering, WebP
encoding, OSS transfer, serialized Git updates and Pages deployment still take
time. Shared storage/network/Git failures can affect multiple services; separate
workers do not eliminate common infrastructure failures. A indefinitely stuck
worker still blocks its own service and must be investigated; do not blindly
kill publishers while they update shared catalogs. Existing-output retries are
bounded per invocation and continue in future scheduled invocations.

### Connectivity Checks

```bash
ssh -i ~/.ssh/id_ed25519_iaplacs_github -o IdentitiesOnly=yes -T git@github.com
cd ~/iaplacs-site
env -u LD_LIBRARY_PATH -u LD_PRELOAD GIT_SSH="$HOME/.ssh/git-iaplacs-ssh" /usr/bin/git pull --rebase origin main
env -u LD_LIBRARY_PATH -u LD_PRELOAD GIT_SSH="$HOME/.ssh/git-iaplacs-ssh" /usr/bin/git push --dry-run origin HEAD:main
```
