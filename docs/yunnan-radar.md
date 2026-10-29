# Yunnan Simulated Radar Reflectivity

## Production Approval (2026-10-29)

Approved for latest published WORK_yn2026102812 (Oct28 20BJT) and future runs,
not older archives. `publish_yunnan_radar.sh` selects completed d02 where its
mass fields/time records are available, otherwise d01; calls the NCL renderer
with a code/source cache; uploads PNG/WebP through OSS and commits catalog only.
The normal rain publisher and existing two-minute service audit invoke it.
Independent locking and successful-publication receipts prevent duplicate work;
failed runs are retried. Public catalog merging preserves radar when rain staging
is cleaned. The preview-only paragraphs below record earlier development status.

## Current Preview Method (2026-10-29)

The user approved the manuscript reference diagnostic. The standalone preview
now uses `tools/render_yunnan_radar_ncl.py` and `diagnose_radar_composite.ncl`:
full pressure P+PB, temperature from wrf_tk(P+PB,T+300), QVAPOR, QRAIN,
QSNOW and QGRAUP feed NCL wrf_dbz with ivarint=0 and iliqskin=0. A vertical
maximum is then calculated. Native DBZ is not an input. This fixed-intercept
rain/snow/graupel approximation does not separately model hail or use particle
number/spectrum moments. It is not a repair of the model's native diagnostic.

Inputs are checked for dimensions, missing/nonfinite values and positive pressure
and potential temperature. Negative mixing ratios are counted; the reference NCL
routine clips them internally, without modifying raw model files. Any missing,
nonfinite or >100 dBZ diagnosed output rejects the frame instead of hiding a
column as a white hole. The 100 threshold remains an operational safeguard,
not a scientific validation criterion. The single-time check at Oct28 11 BJT
returned maximum60.0775 dBZ versus native212.118 dBZ. This is a method comparison,
not observational verification. Each source time is selected explicitly rather
than copying the manuscript's fixed time-index0 assumption.

The checked input arrays are written to disposable NetCDFs for NCL; these are
removed on completion. Manifests record method, selected input hash, code hashes,
source signature, actual times and per-time ranges/negative counts. Runtime use
remains isolated under Website/.tmp/work_visibility_check, with no publishing hook.

The following sections document the earlier native-DBZ experiment for comparison.

The standalone `airport_radar` preview is a **model forecast**, not observed
radar data. It uses the vertical maximum of the existing `DBZ` field at each
horizontal grid point. No reflectivity-to-rainfall conversion is applied.

## Method and Source

- Read `DBZ(Time,bottom_top,south_north,west_east)` directly. Choose d02 when it
  contains DBZ and at least 14 times; otherwise use d01. Use the existing Yunnan
  aviation domain bounds and four airport markers.
- The inspected WORK_yn/2026102706 job calls the test20260809 WRF executable.
  Its `phys/module_mp_iap_lacs.F`, lines 707-715, sums hydrometeor reflectivity
  contributions, then applies `10*log10(sum*rho)`, with -150 as its no-echo floor.
  Thus DBZ is already logarithmic dBZ although its NetCDF units attribute is blank.
  The renderer accepts this audited blank-unit convention or explicit dBZ; other
  units fail rather than silently applying a second logarithm.
- The definition of model column-maximum reflectivity follows the
  [WRF-Python diagnostic documentation](https://wrf-python.readthedocs.io/en/latest/internal_api/generated/wrf.g_dbz.get_max_dbz.html).
  We use the model's own microphysics DBZ, not WRF-Python's alternative particle
  assumptions. NOAA explains the distinction between
  [base and composite radar reflectivity](https://www.noaa.gov/jetstream/reflectivity).
  A model vertical maximum is not an actual radar volume scan or lowest tilt.
- Use actual WRF Times after lead 12 h (first output >=13 h), converted to BJT.
  These are instantaneous times, not one-hour accumulation windows.

## Quality Control

The inspected d02 at lead 24 h contains values up to 305.24 dBZ. Do not silently
cap these at a normal strong-echo color. A provisional website QC rule marks a
column unavailable if **any** level is missing, nonfinite, below the model floor -150,
or above 100 dBZ. This conservative whole-column policy prevents reporting a
lower valid level as a reliable maximum when another level is invalid.
The outermost grid ring is also masked. A fully unusable time fails rendering.
At the user's request, masked cells display white without an invalid-cell legend.
This display choice does not turn missing cells into valid no-echo measurements.

The 100 dBZ limit is an operational screening rule, not a validated physical
cutoff or a warning standard. Values from 70 to 100 remain unchanged and use the
colorbar's upper extension. Negative values including
the -150 floor remain valid no/weak echo, displayed white below 5 dBZ. Color
boundaries run from 5 to 70 dBZ in 5 dBZ steps. No interpolation, smoothing,
replacement of suspect values, or modification of the wrfout is performed.

The palette follows the [NMC southwest radar composite](https://www.nmc.cn/publish/radar/xinan.html).
RGB values were sampled from its official PNG colorbar dated 2026-10-29 00:06 BJT:
5/10/15/20/25/30/35/40/45/50/55/60/65 dBZ lower bounds use
`419df1,64e7eb,6dfa3d,00d800,019000,ffff00,e7c000,ff9000,ff0000,d60000,c00000,ff00f0,9600b4`;
the >=70 dBZ extension uses `ad90f0`. This is the website palette, not a claim
that it is a universal mandatory national standard for every radar product.

`production_manifest.json` records the source domain, bounds, file size/mtime,
code and SHP hashes, selected input hash, actual times, raw maximum and QC counts
for every frame. Future model changes require reviewing the blank-units convention
and provisional QC rules; this implementation does not repair the model diagnostic.

## Preview Only

- `tools/render_yunnan_radar.py`: hourly PNGs and montage, 400 dpi, same map fonts
  and airport symbols as aviation products. Twelve times produce 3 rows x 4 columns.
- The user requested separate local preview pages on 2026-10-28. Radar is not
  connected to the airport page, OSS upload, Git publication, or cron.
- Local preview: `.tmp/diagnostic_preview_20261027_06/radar.html` and sibling
  `visibility.html`. Their local PNGs and embedded manifests need no server.
- Default is hourly, with montage, download, zoom and time navigation controls.
  Existing website products and archived case pages remain unchanged.

To generate a local-on-server preview without publishing, call the renderer with
explicit `--input`, `--output`, `--province-shp`, `--city-shp`, and `--domain d02`.
The standalone command does not upload or modify any model files.
