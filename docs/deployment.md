# Deployment Notes

## Do You Need Server Deployment?

For the current GitHub Pages plan, the website itself is not deployed on the IAP server.

The IAP server only needs a scheduled publishing job:

1. read model/observation products;
2. render maps and JSON into a temporary release directory;
3. validate `forecast-runs.json` and image paths;
4. copy the result to `data/current`;
5. commit and push to GitHub.

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
Apply a separate retention job only after the catalog has more history than needed; the
catalog displays the newest eight runs by default.

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

Then run `tools/optimize_forecast_images.sh` and
`python3 tools/build_forecast_catalog.py` before `git add`, so the
website can expose the new 起报时间 automatically after GitHub Pages deploys.
The generated catalog keeps `/` as the airport service, `/ningxia/` as the
WORK_nx/NX product page, and `/shangrao/` as the Shangrao product page.
