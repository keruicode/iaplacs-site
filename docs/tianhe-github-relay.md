# Tianhe GitHub Publisher

The publisher runs on Tianhe itself. It checks the newest completed
`WORK_nx` and `WORK_yn` forecast figures, copies only new products to a local
GitHub Pages checkout, retains five run directories per product family,
rebuilds `data/tianhe/current/forecast-runs.json`, and pushes the result to
GitHub. No Mac cron task is used.

The publisher reads these default Tianhe locations:

```text
/fs2/home/junzhang/zhoubj/WORK_nx
/fs2/home/junzhang/zhoubj/WORK_yn
/fs2/home/junzhang/zhoubj/WORK
/fs2/home/junzhang/zhoubj/WORK_tc
```

It uses ImageMagick when present; otherwise it uses Pillow from the existing
`wrf-scripts` Conda environment to create bounded WebP and preview WebP files.
When available, it runs Git through `/fs2/home/junzhang/kerui/bin/git-system`
to avoid environment library conflicts from scientific-module shells.

No NCL or ImageMagick installation is required for forecast drawing. The
existing Tianhe Conda Python reads the completed WRF files directly and creates:

- `WORK_nx`: a Ningxia regional T13-T48 6x6 precipitation mosaic plus the
  completed nationwide `WORK_nx` mosaic. The Ningxia page defaults to the
  regional image and exposes the nationwide image as its second frame.
- `WORK_yn`: a Yunnan airport T13-T48 6x6 precipitation mosaic with the three
  airport-plane markers and `airport_precip_totals.json`. The catalog shows the
  maximum hourly precipitation and time for each airport.
- `WORK`: Shangrao regional precipitation mosaics.
- `WORK_tc`: not rendered or transferred to the website. It is a storage-only
  source whose completed output is condensed into a precipitation backup.

Intermediate 36-panel PNG files are created only below
`~/.iaplacs-tianhe/rendered/*/.panels` while composing a mosaic, then removed.
Use `--force` to regenerate an already rendered run after a plotting change.

After cloning `iaplacs-site` to `/fs2/home/junzhang/kerui/iaplacs-site`,
verify discovery without changing files:

```bash
tools/tianhe_publish_forecast_to_github.sh --dry-run
```

Install or refresh the managed Tianhe cron entry:

```bash
tools/install_tianhe_publisher_cron.sh
```

The cron entry runs every 15 minutes (minutes 07, 22, 37, and 52) and logs to
`~/.iaplacs-tianhe/logs/github-publisher.log`. It requires Tianhe to reach
GitHub and to have GitHub push authentication configured for the repository.
If GitHub is temporarily unreachable, the publisher still creates the local
catalog commit and retries the push on its next scheduled run. Each Git network
operation has two attempts by default; adjust
`IAPLACS_TIANHE_GIT_NETWORK_ATTEMPTS` or
`IAPLACS_TIANHE_GIT_NETWORK_RETRY_DELAY` only when needed.

## Completed WRF cleanup

The same 15-minute publisher also manages completed WRF output directories.
It creates an atomic, compressed precipitation-only NetCDF backup containing
`Times`, `XLAT`, `XLONG`, `RAINC`, and `RAINNC` below:

```text
/fs2/home/junzhang/kerui/iaplacs-precip-backups/<WORK family>/<YYYYMMDDHH>_precip.nc
```

Only after the corresponding web products are complete and the backup validates
does it remove a superseded stable numeric run directory from `WORK_nx`,
`WORK_yn`, or `WORK`. The newest completed run is never removed, and incomplete
runs are retained. This leaves one complete full WRF run per family until the
next completed run has been rendered and backed up.

`WORK_tc` follows a separate backup-only rule because it has no website product:
once a numeric run's WRF file is stable (at least 20 minutes old and at least
20GB by default), the publisher creates and verifies its precipitation backup,
then deletes that full run immediately. Incomplete or still-writing runs are
never deleted. Set `IAPLACS_TIANHE_WORK_TC_ENABLED=0` to disable only this
`WORK_tc` cleanup.

The defaults keep 10 precipitation backups per family and enable model cleanup.
Set `IAPLACS_TIANHE_DELETE_COMPLETED_MODEL_RUNS=0` to inspect backups without
deleting any WRF output. The `--dry-run` mode reports planned extraction and
cleanup without modifying files.
