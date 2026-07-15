# Deployment Notes

## Do You Need Server Deployment?

For the current GitHub Pages plan, the website itself is not deployed on the IAP server.

The IAP server only needs a scheduled publishing job:

1. read model/observation products;
2. render maps and JSON into a temporary release directory;
3. validate `forecast-runs.json` and image paths;
4. copy the result to `data/current`;
5. commit and push to GitHub.

In production, GitHub Pages is the page and catalog origin. Forecast PNG/WebP
images plus small `.preview.webp` first-screen images are uploaded to Alibaba
OSS before the catalog is generated, and `forecast-runs.json` points Ningxia and
Shangrao frames to the OSS origin. The GitHub image copies remain useful as
repository fallback, but normal browser image requests should go to OSS.

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
python3 tools/build_forecast_catalog.py
test -f data/current/forecast-runs.json
find data/current/maps -type f | head -n 1 >/dev/null

git add data/current tools/build_forecast_catalog.py
git commit -m "Update forecast products $(date +%Y%m%d_%H%M)" || exit 0
git push
```

Do not remove `data/current` during each publish. The run-specific directories already
stored there are what let the Ningxia and Shangrao pages expose several initial times.
Keep only the newest five run directories for each product family. The production
publisher applies this separately to `worknx_summary_*` (Ningxia) and `wrf_montage_*`
(Shangrao), so each page exposes at most five initial times and OSS does not retain
older forecast prefixes.

For production, finish each timestamped run directory before copying it into the repository.

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

Then run `tools/optimize_forecast_images.sh` and
`python3 tools/build_forecast_catalog.py` before `git add`, so the
website can expose the new 起报时间 automatically after GitHub Pages deploys.
With the production OSS setup, keep `IAPLACS_MAX_RUNS=5` and
`IAPLACS_ASSET_BASE_URL` set to the OSS prefix (the catalog builder now defaults to
the production OSS prefix). Verify the public OSS object and CORS response before
publishing the catalog.
The generated catalog keeps `/` and `/ningxia/` on the Ningxia WORK_nx product
service, `/shangrao/` on the Shangrao product service, and `/airpots/` on the
airport sample product service.
