# iaplacs.xyz Static Forecast Site

This repository is the static MVP for `iaplacs.xyz`.

The first version is designed for GitHub Pages:

- no backend server is required for the website itself;
- forecast products are pre-rendered as web assets;
- the browser loads `data/current/forecast-runs.json`, with `manifest.json` kept as a fallback;
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
data/current/maps/shangrao_work_YYYYMMDD_HH/
data/current/maps/worknx_summary_YYYYMMDD_HH/
```

`worknx_summary_*` is exposed only on `/ningxia/`; `wrf_montage_*` and
`shangrao_work_*` are exposed only on `/shangrao/` and are merged when they have
the same initial time. The homepage uses the airport service catalog.

Keep the existing run directories when publishing a new one. Removing
`data/current` before every publish leaves only one selectable initial time; the catalog
builder can expose up to eight retained Ningxia runs and eight retained Shangrao runs.

Then run:

```bash
python3 tools/build_forecast_catalog.py
```

Keep images small and web-friendly:

- WebP preferred for maps;
- PNG allowed when WebP is not available;
- target 300 KB to 800 KB per product image for smooth loading;
- keep only a small number of recent releases in Git.

For a heavier public service, keep the website on GitHub Pages and move large images to object storage/CDN.
