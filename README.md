# iaplacs.xyz Static Forecast Site

This repository is the static MVP for `iaplacs.xyz`.

The first version is designed for GitHub Pages:

- no backend server is required for the website itself;
- forecast products are pre-rendered as web assets;
- the browser loads `data/current/forecast-runs.json`, with `manifest.json` kept as a fallback;
- forecast map images are delivered from the Alibaba OSS origin; GitHub Pages carries the app, catalog, and fallback copies;
- the IAP server can later update files on a schedule and push them here.

Current service routes:

- `/` is the airport weather service entry;
- `/ningxia/` shows WORK_nx/NX Ningxia forecast products;
- `/shangrao/` shows Shangrao forecast products.

## Local Preview

Run from this directory:

```bash
python3 -m http.server 5173
```

Open:

```text
http://127.0.0.1:5173/
```

Do not open `index.html` directly with `file://`; browsers may block JSON loading.

## GitHub Pages Setup

1. Create a GitHub repository, for example `iaplacs-site`.
2. Push this directory to the repository.
3. In repository settings, enable Pages from the `main` branch and root directory.
4. In Pages custom domain, set `iaplacs.xyz`.
5. In Aliyun DNS, add GitHub Pages records:

```text
@     A      185.199.108.153
@     A      185.199.109.153
@     A      185.199.110.153
@     A      185.199.111.153
www   CNAME  <github-user>.github.io
```

Replace `<github-user>` with the GitHub account or organization name.

## Data Update Model

The website only depends on:

```text
data/current/forecast-runs.json
data/current/manifest.json
data/current/maps/*
data/current/stations/*
tools/build_forecast_catalog.py
```

The IAP server should generate or copy a complete new run directory first, validate it, run the catalog builder, then commit both the images and JSON catalog. Current server-published directory patterns are:

```text
data/current/maps/wrf_montage_YYYYMMDD_HH/
data/current/maps/worknx_summary_YYYYMMDD_HH/
```

`worknx_summary_*` is exposed only on `/ningxia/`; `wrf_montage_*` is exposed
only on `/shangrao/`. The homepage uses the airport service catalog.

When a service page opens, the frontend preloads all images in its retained
catalog with a small concurrency limit. Images are reused through in-memory
Object URLs during the session and through the browser's Cache Storage across
reloads. The cache key includes the run publication version, so a newly
published image gets fetched while unchanged images are reused locally. The
full-screen viewer can move left/right through every image in the current
service, including images from other retained runs.

Keep the existing run directories when publishing a new one. Removing
`data/current` before every publish leaves only one selectable initial time; the catalog
builder exposes at most five retained Ningxia runs and five retained Shangrao runs.

The production image path is the OSS origin
`https://iaplacs-forecast-images-hk.oss-cn-hongkong.aliyuncs.com/iaplacs/`.
The server publisher uploads the optimized PNG/WebP assets first, then generates the
catalog with those OSS URLs. OSS retention is also limited to the newest five run
directories per product family: `worknx_summary_*` and `wrf_montage_*`.

Then run:

```bash
tools/optimize_forecast_images.sh
python3 tools/build_forecast_catalog.py
```

Keep images small and web-friendly:

- WebP preferred for maps;
- PNG allowed when WebP is not available;
- run `tools/optimize_forecast_images.sh` before building the catalog;
- keep decoded dimensions bounded for mobile browsers, not only compressed file size;
- target roughly 300 KB to 1.2 MB per product image for smooth loading;
- keep only a small number of recent releases in Git.

For a heavier public service, keep the website and catalog on GitHub Pages while
continuing to serve large images from OSS or a CDN.
