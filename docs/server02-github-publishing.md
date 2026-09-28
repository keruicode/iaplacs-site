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

### Connectivity Checks

```bash
ssh -i ~/.ssh/id_ed25519_iaplacs_github -o IdentitiesOnly=yes -T git@github.com
cd ~/iaplacs-site
env -u LD_LIBRARY_PATH -u LD_PRELOAD GIT_SSH="$HOME/.ssh/git-iaplacs-ssh" /usr/bin/git pull --rebase origin main
env -u LD_LIBRARY_PATH -u LD_PRELOAD GIT_SSH="$HOME/.ssh/git-iaplacs-ssh" /usr/bin/git push --dry-run origin HEAD:main
```
