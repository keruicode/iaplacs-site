# Deployment Notes

## Do You Need Server Deployment?

For the current GitHub Pages plan, the website itself is not deployed on the IAP server.

The IAP server only needs a scheduled publishing job:

1. read model/observation products;
2. render maps and JSON into a temporary release directory;
3. upload optimized image assets to OSS and validate public URLs;
4. generate `data/current/forecast-runs.json` with OSS image URLs;
5. commit and push the small catalog files to GitHub.

In production, GitHub Pages is the page and catalog origin. Forecast PNG/WebP
images plus small `.preview.webp` first-screen images are uploaded to Alibaba
OSS before the catalog is generated, and `forecast-runs.json` points Ningxia,
Shangrao, and Yunnan airport frames to the OSS origin. GitHub no longer tracks routine generated
forecast images; `data/current/maps/*` is a server-local build cache.

After the first image renders, the frontend uses `requestIdleCallback` (with a
timer fallback) to warm the active service's preview and medium viewer images
one at a time using native image requests. This is intentionally not a
cross-origin `fetch`/Blob or Cache Storage workflow: OSS can serve an image to
an `<img>` without granting JavaScript CORS access. Native requests reuse the
browser HTTP cache when the viewer opens, while their temporary `Image` objects
are released instead of retaining every decoded 3200px bitmap in memory. The
warmup is skipped when Save-Data or a 2G connection is reported. Do not add a
changing timestamp to every render; the publication version in the catalog is
what lets unchanged images remain locally cacheable while new products
invalidate only their own URLs.

GitHub Pages then serves the updated static files.

## Enable GitHub Pages After Push

Current GitHub repository:

```text
git@github.com:keruicode/iaplacs-site.git
```

On GitHub:

1. Open the `keruicode/iaplacs-site` repository.
2. Go to `Settings` -> `Pages`.
3. In `Build and deployment`, set `Source` to `Deploy from a branch`.
4. In `Branch`, select:

```text
main
/
```

5. Click `Save`.
6. Wait for the deployment. GitHub says Pages changes can take up to about 10 minutes to publish.

The temporary project URL should be:

```text
https://keruicode.github.io/iaplacs-site/
```

This repository already has a `CNAME` file containing:

```text
iaplacs.xyz
```

If GitHub does not automatically show that custom domain in `Settings` -> `Pages`, enter `iaplacs.xyz` manually after Pages has been enabled.

## When a Real Server Becomes Necessary

Add a backend server later only if the site needs:

- login or access control;
- database queries;
- very large historical archive search;
- user-submitted jobs;
- real-time computation;
- APIs for other systems.

## Future Publishing Script Shape

The IAP server can run a scheduled script similar to:

```bash
#!/usr/bin/env bash
set -euo pipefail

SITE_REPO="$HOME/iaplacs-site"
PRODUCT_DIR="/path/to/generated/run-directories"

cd "$SITE_REPO"
git pull --ff-only

mkdir -p data/current/maps
rsync -a "$PRODUCT_DIR"/ data/current/maps/

tools/optimize_forecast_images.sh
# Upload PNG/WebP/preview WebP files from data/current/maps/ to OSS here.
# The catalog builder defaults to the production OSS prefix.
python3 tools/build_forecast_catalog.py
test -f data/current/forecast-runs.json
find data/current/maps -type f | head -n 1 >/dev/null

git add data/current/forecast-runs.json data/current/manifest.json
git commit -m "Update forecast products $(date +%Y%m%d_%H%M)" || exit 0
git push
```

Do not remove the server-local `data/current/maps` cache during each publish. The
run-specific directories stored there are what let the catalog builder expose
several initial times. Keep only the newest five run directories for each product
family. The production publisher applies this separately to `worknx_summary_*`
(Ningxia), `wrf_montage_*` (Shangrao), and `airport_yunnan_*` (Yunnan airports), so each page exposes at most five
initial times and OSS does not retain older forecast prefixes.

For production, finish each timestamped run directory before copying it into the
server-local `data/current/maps` cache and uploading it to OSS.

For the current Shangrao WRF montage workflow, the server publishing helper should copy
`*_combined_*_grid.png` files into:

```text
data/current/maps/wrf_montage_YYYYMMDD_HH/
```

For the current Ningxia/WORK_nx workflow, copy the summary image plus its
`manifest_fragment.json` into:

```text
data/current/maps/worknx_summary_YYYYMMDD_HH/
```

For the Yunnan airport/WORK_yn workflow, copy the regional overview image,
`manifest_fragment.json`, and `airport_precip_totals.json` into:

```text
data/current/maps/airport_yunnan_YYYYMMDD_HH/
```

For the Ningxia regional replacement, render from the corresponding
`wrfout_d01_*` files rather than cropping the existing nationwide sheet:

```bash
tools/render_worknx_ningxia_overview.sh --recent 5
```

The renderer drops T01-T12, produces exactly 36 hourly T13-T48 panels, and
combines them into one Ningxia-only 6x6 overview per initialization. On
`login02`, use the regional wrapper for both rendering and publication:

```bash
tools/publish_worknx_ningxia_to_github.sh --recent 5
```

The wrapper passes each overview through the normal OSS/GitHub publisher into
the matching `worknx_summary_YYYYMMDD_HH/` directory. The catalog builder
prioritizes that `*_combined_overview_6x6_grid` product over a legacy nationwide
image when both temporarily exist in the same run directory. The hourly cron
must run this wrapper, not `publish_worknx_summary_to_github.sh` directly.

For the airport service, render the latest complete `WORK_yn` initialization
over the Yunnan bounding box, draw the three airport markers, calculate point
precipitation totals, and publish the latest run with:

```bash
tools/publish_worknx_yunnan_airports_to_github.sh --latest
```

This wrapper produces one 36-hour 6x6 overview, creates WebP and preview WebP
derivatives, uploads them to OSS, and commits only `data/current/forecast-runs.json`
plus `data/current/manifest.json`. It uses the image files inside the GitHub
worktree only as a transient catalog-building cache and removes that cache on
exit; routine forecast images must not be committed to GitHub.

Deploy the required administrative-boundary Shapefiles to
`login02:/data1/elpt_2022_00083/kerui/Website/SHP/`:

```text
省界_region.{shp,shx,dbf,prj,sbn,sbx}
ningxia_city_county.{shp,shx,dbf,prj,cpg}
shangrao_city_county.{shp,shx,dbf,prj,cpg}
yunnan_city_county.{shp,shx,dbf,prj,cpg}
```

The Ningxia renderer draws `ningxia_city_county.shp` as the thin city/county
layer and `省界_region.shp` as the thicker province outline. The deployable
Shangrao NCL script is `tools/rain_wrf_shangrao_hour_bjt.ncl`; when copied into
the server WRF montage workflow, run it with:

```bash
SHANGRAO_PROVINCE_SHP_FILE="$PWD/SHP/省界_region.shp" \
SHANGRAO_COUNTY_SHP_FILE="$PWD/SHP/shangrao_city_county.shp" \
ncl rain_wrf_shangrao_hour_bjt.ncl
```

Do not use a nationwide county layer in these two products. The committed
county Shapefiles are filtered to Ningxia and Shangrao only.

The Yunnan airport renderer draws `yunnan_city_county.shp` as the thin
city/county layer and `省界_region.shp` as the thicker province outline. Do not
use a nationwide county layer in the operational product.

For cron, install the incremental Yunnan checker instead of the heavyweight
publisher. It checks for a new complete `WORK_yn` wrfout and only then renders
and publishes:

```bash
tools/publish_workyn_yunnan_airports_if_new.sh
```

Then run `tools/optimize_forecast_images.sh`, upload the generated assets to
OSS, and run `python3 tools/build_forecast_catalog.py` before `git add`, so the
website can expose the new 起报时间 automatically after GitHub Pages deploys.
With the production OSS setup, keep `IAPLACS_MAX_RUNS=5` and
`IAPLACS_ASSET_BASE_URL` set to the OSS prefix (the catalog builder now defaults to
the production OSS prefix). Verify the public OSS object and CORS response before
publishing the catalog. Do not `git add data/current/maps`; those generated image
directories are intentionally ignored by Git. Keep historical raster archives on
the IAP server output directory and OSS, not in the Mac checkout or GitHub.
The generated catalog keeps `/` and `/ningxia/` on the Ningxia WORK_nx product
service, `/shangrao/` on the Shangrao product service, and `/airpots/` on the
Yunnan airport product service when available.
