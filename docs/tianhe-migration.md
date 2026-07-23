# IAP Runtime Backup and Tianhe Staging

The IAP runtime is backed up as a small, versioned archive. It includes the
automation scripts, Python/NCL plotting code, SHP inputs, publish state,
`batch_ncks.sh`, and the active crontab. It excludes credentials, SSH keys,
Git metadata, logs, raw WRF files, and rendered forecast images.

On IAP, install the daily 03:15 backup after copying the three helper scripts
to the runtime root:

```bash
cd /data1/elpt_2022_00083/kerui/Website
chmod +x backup_iap_runtime.sh install_iap_backup_cron.sh sync_iap_runtime_to_tianhe.sh
./install_iap_backup_cron.sh
./backup_iap_runtime.sh
```

The archive and its SHA-256 checksum are written below:

```text
/data1/elpt_2022_00083/kerui/Website/backups/runtime/
```

To stage the latest snapshot on Tianhe, run from IAP once SSH key access to
`sunjm@192.168.4.11` is available and its host key has been added to IAP's
`~/.ssh/known_hosts`:

```bash
cd /data1/elpt_2022_00083/kerui/Website
./sync_iap_runtime_to_tianhe.sh
```

It creates these Tianhe paths without enabling a Tianhe cron job:

```text
/fs1/home/sunjm/kerui/iaplacs-runtime/backups/
/fs1/home/sunjm/kerui/iaplacs-runtime/releases/<timestamp>/
/fs1/home/sunjm/kerui/iaplacs-runtime/current -> releases/<timestamp>/
```

If IAP cannot route to Tianhe but the local Mac can reach both systems, use
the local relay instead. It uses SFTP for the file transfer, verifies the
archive checksum on both ends, and deletes its local temporary directory:

```bash
tools/relay_iap_runtime_to_tianhe.sh
```

Before using the staged code on Tianhe, provide the Tianhe paths for `WORK_nx`,
`WORK_yn`, the WRF preprocessing source, Slurm partition/account, NCL and
ImageMagick environments, the GitHub publishing host/key, and OSS credentials.
Do not copy the IAP credential files into this archive. Configure Tianhe with
its own least-privilege credentials and then install a separate Tianhe crontab.

When using the Tianhe login environment, run Git through
`/fs1/home/sunjm/kerui/bin/git-system`. It unsets the injected dynamic-library
paths before invoking `/usr/bin/git`, avoiding the system `libssh` and Spack
OpenSSL ABI conflict.

## One-week GitHub-only transition

The Tianhe transition can publish directly to GitHub Pages without OSS. After
the initial HTTPS clone has completed, run the publisher from that checkout for
each completed run directory:

```bash
cd /fs1/home/sunjm/kerui/iaplacs-site
GIT_BIN=/fs1/home/sunjm/kerui/bin/git-system \
  tools/publish_forecast_to_github_pages.sh \
  --source-dir /path/to/completed/worknx-or-wrf-run \
  --family worknx_summary \
  --run-prefix 20260723_00
```

Use `wrf_montage` for Shangrao and `airport_yunnan` for the Yunnan airport
product. The script copies only top-level product images and JSON, creates WebP
and preview WebP assets where PNG is supplied, removes PNG by default, retains
at most five directories for each product family, rebuilds the catalog with
relative GitHub Pages URLs, and commits both additions and old-run deletions in
one push. Historical PNG output remains in the compute/output directories and
is never deleted by this publisher.

During gradual migration, the catalog preserves older existing entries until a
family has five GitHub-hosted runs. Once all active families have been seeded,
add `--local-only` to remove remaining legacy OSS-only catalog entries.

## Tianhe account migration through the Mac

The old Tianhe account is `sunjm@192.168.4.11:/fs1/home/sunjm/kerui`; the new
account is `junzhang@192.168.10.50:/fs2/home/junzhang/kerui`. Because both VPNs
are available only on the Mac, run this from the local website checkout:

```bash
tools/relay_tianhe_kerui_account.sh
```

The helper creates a temporary archive under `/tmp` on the old account, moves
it through a local `mktemp` directory with SFTP, verifies SHA-256 both locally
and on the new account, extracts to a unique target-side staging directory, and
only then moves `kerui` to its final destination. It never writes below
`/fs2/home/junzhang/zhoubj`. It removes the local staging directory, the source
archive, and the target-side archive/staging directory after a successful run;
on failure it also removes only those uniquely named temporary paths. It refuses
to overwrite a nonempty `/fs2/home/junzhang/kerui`; an existing empty directory
is removed only after a complete archive has been verified and extracted into
the separate staging path.
