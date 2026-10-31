# WORK Visibility Postprocessing

## Regional and Outer-Domain Views

Yunnan/Xinjiang visibility now publishes two views via
`render_regional_visibility.py`: the regional view prefers d02; the wide view
uses the same initialization's d01 and its complete horizontal coordinate bounds
(rounded outward to whole degrees). No province mask or 150E cap is applied to
these wide views. Labels are 云南区域 / 中国西南部 and 新疆区域 / 中国西北部.
Each domain independently selects native VIS_MIN, VIS, or the cloud diagnostic.
All paths use the lowest mass-grid model level (`bottom_top=0`). Diagnostic
inputs are read as `[time, 0, :, :]` for every thermodynamic and cloud-moment
field; no vertical averaging or minimum is taken. This is not a fixed 2 m height.
The regression test gives the upper layer invalid values and verifies that the
calculated visibility still equals the valid first-layer calculation.
Unavailable inputs are not replaced with another initialization's data.
Both views retain hourly/montage modes. Child manifests and per-domain sources
are preserved, while the combined manifest contains both area frames; unchanged
children do not rerender. Old flat single-view files owned by their manifest are
retired after the new manifest succeeds. Existing public OSS assets remain until
normal retention cleanup. The airport visibility sidebar description is empty
and the frontend suppresses stale duplicate descriptions in older catalogs.

## Current Status: Production Approved

As of 2026-10-31, WORK2026103006 and later read **VIS_MIN**, first vertical
level (zero-based index 0), in metres. No automatic fallback to VIS is allowed.
Earlier published VIS history is retained without replotting. The visible button,
FOG palette, white invalid cells and regional/national views remain unchanged.
The variable metadata says "mini visibility"; its exact accumulation/reset window
has not been verified from model source. Timestamps remain the file's valid Times;
do not label this as an independently verified hourly average or runway visibility.

The renderer exposes `--variable VIS_MIN|VIS|auto --profile ningxia|yunnan|xinjiang
--domain d01|d02`. Following user approval on 2026-10-31, Yunnan and Xinjiang
are connected to automatic publication from run20261030_00 onward. Their wrapper
uses `--variable auto`: prefer VIS_MIN in the selected domain, otherwise VIS,
and record/show the actual variable. Prefer a usable d02, otherwise d01, from
the same initialization. Ningxia remains strictly VIS_MIN on d01.
After further approval on 2026-10-31, missing both native variables now invokes
the FOG cloud-moment diagnostic fallback for Yunnan/Xinjiang only, when complete
QCLOUD/NW/NW_Z (or numbered spectra) plus P/PB/T/QVAPOR are available. Missing
these inputs skips cleanly, without upload or empty webpage buttons. The fallback
is instantaneous cloud-only visibility, not hourly-minimum VIS_MIN; the product
unit and provenance explicitly identify it as diagnostic. See
[Cloud Visibility Method](cloud-visibility-preview.md). The original WRF signature
and diagnostic code hashes control caching. Native fields are selected before
the diagnostic cache, allowing automatic replacement on later output updates.
The existing two-minute audits and completed-rain publisher hooks retry and
publish new products to OSS. No separate cron or laptop scheduler is needed.
Regional views use existing regional bounds when falling back to d01, and actual
bounds for d02. Wide views always use the complete d01 extent. Both retain airport
markers, the same visibility palette and QC. Raw WRF is unchanged.
Use `publish_work_visibility.sh --run YYYYMMDD_HH --profile yunnan` (or xinjiang)
for the same manual workflow. Products appear only after valid images exist.

The following describes the original integration; VIS references apply to older
history. The current Ningxia production wrapper explicitly selects VIS_MIN.

On 2026-10-29 the user approved production integration for the latest published
run and future runs only. The VIS lower bound is WORK2026102718 (Oct28 02BJT).
Rain publication and the existing two-minute audit invoke the independent VIS
wrapper; completion, source cache, lock, receipt and retry checks remain active.
Set IAPLACS_PUBLISH_VISIBILITY=0 for an emergency operator disable. Earlier
historical runs are not backfilled. Missing VIS skips without inventing data.

The homepage visibility product reads `VIS(Time,bottom_top,south_north,west_east)`
in metres from `WORK` d01. It uses the lowest model level, not a fixed 2 m or
10 m height. It does not recalculate VIS, alter WRF, or change model inputs.

## Display and QC

- Read actual UTC `Times`, convert to BJT and display instantaneous valid times.
  Start at forecast lead 13 hours, after the existing 12-hour spin-up. These are
  snapshots, not hourly accumulations; the UI must not subtract an hour.
- Exclude the outermost grid cell ring, which is uncomputed in the audited
  specified-boundary run. Mask missing/nonfinite, nonpositive and >100000 m values.
  The 100 km threshold is a provisional QC rule, not a meteorological standard.
- Preserve valid numeric values, including exactly 10000 m. The audited model
  initializes VIS to 10000 m; this is not evidence of a precise 10 km prediction.
- Invalid cells display white at the user's request, without an invalid-cell
  legend. Their internal mask and QC records remain intact; white does not prove
  valid high visibility. No interpolation or silent clipping is performed.
- If an entire selected hour has no valid interior data, fail without publishing
  the new manifest. Rainfall products remain independent.
- Use the FOG reference palette: brown/red/orange/yellow/light yellow/white at
  50,100,200,500,1000 m boundaries. FOG calculations are not imported.
- `production_manifest.json` records per-hour QC counts, input data hash, source
  size/mtime, renderer/helper/SHP hashes and QC version.

The source diagnostic inspected on 2026-10-28 uses cloud-droplet extinction.
Do not describe it as observed visibility, runway visual range, or a complete
rain/snow/aerosol visibility diagnostic. Source inspection and numerical evidence
are retained in the local-only project handoff.

## Scripts and Publication

`tools/render_work_visibility.py` renders regional and central-eastern China
hourly/montage products. The latter follows the model extent, capped at 150 E,
matching the precipitation product. PNGs are 400 dpi, with Times New Roman and
Songti SC fonts. The server runtime stores these scripts under `Website/scripts`.

`tools/publish_work_visibility.sh --run YYYYMMDD_HH` reads only completed WORK
runs from 20261027_06 onward. Output is
`Website/worknx_ningxia_overview/YYYYMMDD_HH/visibility/`.
Missing VIS is an explicit skip, not a synthetic substitute. A separate lock
prevents concurrent visibility writers. Matching signatures reuse images;
a manifest-hash receipt is written only after successful OSS/Git publication.

The existing publisher `publish_airport_aviation_to_oss.sh` also accepts
`--family worknx_summary --visibility-dir DIR`. It uploads under the run's
`visibility/` prefix, builds catalog entries, and keeps full-resolution PNG
downloads plus WebP display images. Other combinations remain rejected.

The existing Ningxia publisher calls this independent postprocessor after rain
publication. The existing two-minute audit retries missing/failed visibility
without rerendering rainfall. A ten-minute grace interval prevents repeated
uploads while Pages is still deploying; this does not delay first publication.
No new crontab entry is necessary. Catalog merging retains OSS-only visibility
products after temporary server02 rasters have been cleaned. Existing rolling-run
retention applies to the same run prefix.

## Manual Preview

Run on the data server, with output outside production run directories:

```bash
python3 scripts/render_work_visibility.py \
  --input /path/to/wrfout_d01_YYYY-MM-DD_HH:00:00 \
  --output /path/to/isolated_visibility_preview \
  --province-shp /path/to/province.shp \
  --county-shp /path/to/ningxia_city_county.shp \
  --start 13 --count 2
```

This command does not upload. If a live source changes during the read it fails
for retry; production publication always requires `SUCCESS COMPLETE WRF`.
