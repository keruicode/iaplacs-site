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

Before using the staged code on Tianhe, provide the Tianhe paths for `WORK_nx`,
`WORK_yn`, the WRF preprocessing source, Slurm partition/account, NCL and
ImageMagick environments, the GitHub publishing host/key, and OSS credentials.
Do not copy the IAP credential files into this archive. Configure Tianhe with
its own least-privilege credentials and then install a separate Tianhe crontab.
