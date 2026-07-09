# iaplacs.xyz Static Forecast Site

This repository is the static MVP for `iaplacs.xyz`.

The first version is designed for GitHub Pages:

- no backend server is required for the website itself;
- forecast products are pre-rendered as web assets;
- the browser loads `data/current/manifest.json`;
- the IAP server can later update files on a schedule and push them here.

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
data/current/manifest.json
data/current/maps/*
data/current/stations/*
```

The IAP server should generate a complete new release directory first, validate it, then update `data/current`. Keep images small and web-friendly:

- WebP preferred for maps;
- PNG allowed when WebP is not available;
- target 300 KB to 800 KB per product image for smooth loading;
- keep only a small number of recent releases in Git.

For a heavier public service, keep the website on GitHub Pages and move large images to object storage/CDN.
