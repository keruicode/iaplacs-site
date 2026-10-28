# WORK Visibility Postprocessing

## Current Status: Preview Only

On 2026-10-28 the user requested two independent local preview pages before
website integration. Automatic VIS hooks have therefore been removed from the
rain publisher and audit. `publish_work_visibility.sh` exits without publishing
unless `IAPLACS_PUBLISH_VISIBILITY=1` is explicitly set. Do not enable it until
the user approves the standalone preview. The integration description below
documents the prepared implementation, not currently enabled automation.

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
- Invalid cells are gray, separate from white high-visibility cells and white
  space outside model coverage. No interpolation or silent clipping is performed.
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
