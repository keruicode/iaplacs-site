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

The two-minute cycle checks only the latest completed/output run of each service,
sequentially in the existing allocation. Numerical thread caps and the global
nonblocking cycle lock remain unchanged. After all current chart checks, it
checks the latest Ningxia NC download. Every 20 minutes one service receives a
historical audit (five output runs, up to eight model runs); the service rotates,
so all three receive a historical audit in approximately one hour. Actual timing
depends on job duration and queue availability. Maintenance is deferred when a
current stage fails, and targeted WRF hook calls do not run history maintenance.
The first cycle initializes the maintenance clock without immediately doing a
full history scan. A failed maintenance service does not prevent rotation.

Cycle logs include stage start/end and elapsed seconds. Product publishers may
still combine rendering and upload in one stage; do not interpret that elapsed
time as pure upload time. The auditor drains listing pipelines instead of using
early-closing `head`, preventing SIGPIPE/exit 141 under `pipefail`. A successful
priority visibility check is reused within that audit, but a failed/busy check
does not suppress the later retry.

## NetCDF Downloads

`config/ningxia-downloads.enabled` enables the independent download stage after
the current chart audits. The fast cycle uses `--recent 1`; Ningxia historical
maintenance uses `publish_ningxia_downloads.sh --recent 5` to check completed
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

### Simplified Download Layout (Exporter Version 4)

Only necessary array dimensions remain: `Time`, `south_north`, `west_east`,
and `Time_12H`/`Time_24H` when those accumulation products are available;
there are no numeric dimension-coordinate variables. `Times(Time)` is a NetCDF
string array of UTC `YYYY-MM-DD_HH:MM:SS` values, not a character-code matrix.
This uses readable WRF-style dates but not WRF's S1/DateStrLen storage encoding.
`XLAT`/`XLONG` are two-dimensional native-grid latitude/longitude.
There are no `XTIME`, `bounds`, extra time variables or Lambert projection
attributes. Geographic coordinates remain available for mapping.

Hourly products share `Times`. Accumulations have compact independent dimensions
whose lengths equal the actual eligible complete 08/20 BJT windows. Their
`interval_start` and `interval_end` attributes contain semicolon-separated UTC
timestamps in the same order as the records, with `interval_order` documenting
this mapping. No empty hourly slots, extra time variables, or zero-filled
forecasts are added. A typical 36-hour run has 24 hourly records, two 12-hour
accumulations and one 24-hour accumulation; counts are calculated, not hardcoded.

| Variable | Meaning |
| --- | --- |
| `RAIN_1H`, `RAIN_12H`, `RAIN_24H` | Interval precipitation in mm, not cumulative RAINNC |
| `SOLID_1H` | Hourly snow/graupel/hail water equivalent, mm |
| `VIS_MIN` or `VIS` | Actual selected source name, lowest model layer, m |
| `MDBZ` | Quality-controlled vertical maximum of native DBZ, dBZ |
| `SLWP_CLOUD`, `SLWP_RAIN` | Supercooled cloud/rain column water paths, g/m2 |

These are derived website products, not full WRF output/restart files.
No vertical dimension is invented for a column integral or lowest-layer field.
SLWP means Supercooled Liquid Water Path. `SLWP_CLOUD` and `SLWP_RAIN` are the
cloud and rain contributions. Version 4 changes layout only; numerical algorithms
and the selected time windows are unchanged.

Objects are stored under the existing retention-managed run prefix:
`data/current/maps/worknx_summary_YYYYMMDD_HH/downloads/`.
The NC name includes its content hash. `upload_ningxia_download.sh` transfers to
server02, uploads the NC, downloads it back to verify SHA-256, then publishes
`index.json` last. A later retry verifies the public index and NC availability.
No NC binaries enter Git. Existing run-prefix retention covers these objects.

The Ningxia page reads the selected run's OSS index, exposes a download only
when its schema/run/file match, and cancels stale requests when users change runs.
The OSS object sets Content-Disposition for cross-origin browser downloads.
The saved filename is `ningxia_YYYYMMDDHH_dNN.nc`, without the internal hash.
The OSS key still contains the content fingerprint for cache isolation and
integrity checks. The frontend uses `?download=1` to avoid reusing a previously
cached response with the old filename. Receipt checks validate the download
filename header as well as object/index availability; old headers are repaired
by reuploading the same verified object, without recomputing numerical products.
No extra server or access key is placed in frontend code.

## Backup and Deployment Policy

Before every change to `wrf-scripts`, save a timestamped full before snapshot in
`Website/backups/`. Verify the production file hash has not changed since review.
After isolated tests and deployment, save an after snapshot and the patch.
Never overwrite the initial 20261122 baseline. Website files and crontab must
also be backed up before deployment; no unrelated model scripts or cron entries
are modified. Test scientific code only locally or in an isolated `plot` job,
never directly on login nodes. Do not enable either flag before testing succeeds.
