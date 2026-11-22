# WRF Website Hook and Regional Downloads

## Scope

The shared `wrf-scripts/utils/submit_job.py` only emits a Website hook for
`job_name == "plot_rain"` in the explicitly allowed `WORK`, `WORK_yn`, and
`WORK_xj/YYYYMMDDHH/gfs` directories. Other jobs are unchanged.
The batch calls `Website/scripts/website_after_wrf.sh` after its original plot
command. It preserves the original exit code, independently logs Website failure,
caps numerical libraries at one thread, and requests 16 GiB for these jobs.
The Website hook verifies the live compute allocation before doing any work.

The hook is enabled by `Website/config/website-wrf-hook.enabled`. Removing that
file disables the hook without changing the WRF submission code. Existing Slurm
jobs retain their originally submitted script and do not receive this hook.

`run_website_cycle.sh --service ningxia|yunnan|xinjiang` uses the same global
cycle lock as the existing two-minute cron. It audits missing products and retries
publication through the existing publishers. Busy invocations defer to cron.
The hook does not bypass `afterok`, and failed WRF runs with usable output remain
the responsibility of the existing audit policy.

## NetCDF Downloads

`config/ningxia-downloads.enabled` enables the independent download stage after
the Ningxia audit. `publish_ningxia_downloads.sh --recent 5` checks completed
model runs; `--render-only YYYYMMDD_HH` writes locally without uploading.
The latter still requires a live compute allocation.

`export_ningxia_download.py` prefers the available d02 via its shell caller,
otherwise uses d01. It crops the native grid to 104–107.8 E, 35–39.7 N and masks
cells outside that rectangle. It does not interpolate or pretend a d01 crop is
a nested domain. Only hourly output with at least 13 forecast hours is accepted.
Products begin at forecast hour 13 and end at the available time or hour 48.

The package includes available website numerical fields:

- Hourly precipitation: differences of RAINC + RAINNC + available GRAUPELNC/HAILNC,
  matching the current website formula. This exporter does not redefine it.
- Solid precipitation: differences of available SNOWNC + GRAUPELNC + HAILNC.
- Lowest-layer visibility: VIS_MIN first, otherwise VIS, with source and time
  semantics recorded; no diagnostic fallback is silently substituted.
- Composite reflectivity: the same Ningxia valid-level native DBZ maximum/QC.
- Supercooled cloud/rain water paths: existing thermodynamics and layer integrals.
- 12/24-hour precipitation on full 08/20 BJT windows after the 12-hour spin-up.

Optional missing source fields are omitted and listed accurately in the index.
Missing cells remain missing, not zero. Native float32 output uses zlib/shuffle,
no quantization or reduced grid resolution. Coordinates, UTC times, interval
start/end strings, units, source domain, input signature and helper hashes are retained.

### WRF-style Download Layout (Exporter Version 2)

Dimensions use `Time`, `south_north`, `west_east`, and `DateStrLen`.
`Times` contains UTC `YYYY-MM-DD_HH:MM:SS` strings, as in WRF; `XTIME` is
minutes since initialization. `XLAT`/`XLONG` use WRF's three-dimensional layout.
Hourly interval starts are readable in `Times_START`; `Times` is the end.
Accumulations use `Time_12H`/`Time_24H`, with `Times_12H`/`Times_24H` and
corresponding `_START` strings. There are no numeric `bounds` variables.

| Variable | Meaning |
| --- | --- |
| `RAIN_1H`, `RAIN_12H`, `RAIN_24H` | Interval precipitation in mm, not cumulative RAINNC |
| `SOLID_1H` | Hourly snow/graupel/hail water equivalent, mm |
| `VIS_MIN` or `VIS` | Actual selected source name, lowest model layer, m |
| `MDBZ` | Quality-controlled vertical maximum of native DBZ, dBZ |
| `SLWP_CLOUD`, `SLWP_RAIN` | Supercooled cloud/rain column water paths, g/m2 |

These are derived website products, not full WRF output/restart files.
No vertical dimension is invented for a column integral or lowest-layer field.
Version 2 changes names/layout only; numerical algorithms are unchanged.

Objects are stored under the existing retention-managed run prefix:
`data/current/maps/worknx_summary_YYYYMMDD_HH/downloads/`.
The NC name includes its content hash. `upload_ningxia_download.sh` transfers to
server02, uploads the NC, downloads it back to verify SHA-256, then publishes
`index.json` last. A later retry verifies the public index and NC availability.
No NC binaries enter Git. Existing run-prefix retention covers these objects.

The Ningxia page reads the selected run's OSS index, exposes a download only
when its schema/run/file match, and cancels stale requests when users change runs.
The OSS object sets Content-Disposition for cross-origin browser downloads.
No extra server or access key is placed in frontend code.

## Backup and Deployment Policy

Before every change to `wrf-scripts`, save a timestamped full before snapshot in
`Website/backups/`. Verify the production file hash has not changed since review.
After isolated tests and deployment, save an after snapshot and the patch.
Never overwrite the initial 20261122 baseline. Website files and crontab must
also be backed up before deployment; no unrelated model scripts or cron entries
are modified. Test scientific code only locally or in an isolated `plot` job,
never directly on login nodes. Do not enable either flag before testing succeeds.
