# server02 GitHub Publishing

`server02` publishes IAP-LACS catalog updates to `keruicode/iaplacs-site`.

## Deploy Key

- Private key: `~/.ssh/id_ed25519_iaplacs_github`
- SSH wrapper: `~/.ssh/git-iaplacs-ssh`
- The matching public key is a repository Deploy Key with write access.
- IAP publisher scripts must pass the server-side key path:
  `/public/home/elzd_2023_00026/.ssh/id_ed25519_iaplacs_github`.

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
