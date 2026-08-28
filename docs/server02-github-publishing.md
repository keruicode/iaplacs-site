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

`ensure_iaplacs_ssh_state.sh` restores the missing IAP-to-server02 `id_rsa`,
rewrites the dedicated GitHub key/wrapper, and deliberately does **not** alter
`authorized_keys`. The latter is login authorization managed by the platform
or user and must never be blindly replaced by automation.

The user crontab runs this recovery once per hour:

```cron
0 * * * * /data1/elpt_2022_00083/kerui/Website/ensure_iaplacs_ssh_state.sh >> /data1/elpt_2022_00083/kerui/Website/logs/ssh-state-recovery.log 2>&1
```

Run the following after a `.ssh` reset, or to verify the state immediately:

```bash
/data1/elpt_2022_00083/kerui/Website/ensure_iaplacs_ssh_state.sh
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

```bash
ssh -i ~/.ssh/id_ed25519_iaplacs_github -o IdentitiesOnly=yes -T git@github.com
cd ~/iaplacs-site
env -u LD_LIBRARY_PATH -u LD_PRELOAD GIT_SSH="$HOME/.ssh/git-iaplacs-ssh" /usr/bin/git pull --rebase origin main
env -u LD_LIBRARY_PATH -u LD_PRELOAD GIT_SSH="$HOME/.ssh/git-iaplacs-ssh" /usr/bin/git push --dry-run origin HEAD:main
```
