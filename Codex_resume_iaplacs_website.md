# Codex Resume: iaplacs.xyz Website Planning

Last updated: 2026-07-12 18:55 CST

## Resume Commands

```bash
codex resume 019f472c-9bd3-7222-9160-5fa0162a1249
```

```bash
code resume 019f472c-9bd3-7222-9160-5fa0162a1249
```

Latest diagnostic follow-up in this thread:

```bash
codex resume 019f54bd-2333-7323-a89d-92bf699aec95
```

```bash
code resume 019f54bd-2333-7323-a89d-92bf699aec95
```

## Thread

- Thread ID: `019f472c-9bd3-7222-9160-5fa0162a1249`
- Session log: `/Users/xiaoxiaotu/.codex/sessions/2026/07/09/rollout-2026-07-09T21-58-53-019f472c-9bd3-7222-9160-5fa0162a1249.jsonl`
- Working directory: `/Users/xiaoxiaotu/_01_IAP/Website`

## User Goal

The user bought `iaplacs.xyz` on Alibaba Cloud/万网 and wants to build a website backed by data on an IAP server. The long-term product should resemble a professional weather forecast service, but with a more modern, calm, technology-oriented research-institute style.

## Current State

- Workspace was empty at the start of this thread.
- Workspace is now a Git repository on branch `main`.
- Created a Step 0 planning document with deployment architecture, domain/备案 path, data publishing model, server inspection checklist, and visual/product direction.
- Answered an ICP filing form question: Alibaba Cloud 备案服务码 only applies when the website/App is hosted on an eligible Alibaba Cloud mainland China resource. If the Beijing IP is not an Alibaba Cloud mainland resource, the user should file through the real server/access provider instead of trying to use Alibaba Cloud's service code.
- Clarified how to find an Alibaba Cloud ICP 备案服务码: if the user only bought the domain, there is no service code; if they bought an eligible Alibaba Cloud mainland ECS/轻量服务器, check the ICP filing console/service-code management console or let the filing flow auto-generate it when the server and filing account are the same.
- Clarified that if the user has no Alibaba Cloud server, they cannot fill an Alibaba Cloud ICP service code. They must either buy an eligible Alibaba Cloud mainland server/resource, or file through the real server/access provider. For the intended IAP-LACS public forecast/data service, personal filing may be inappropriate; unit/事业单位 filing is likely the better long-term route.
- Clarified OSS filing implications: Alibaba Cloud OSS custom domains require ICP filing when used for website/static-file access, but OSS is not the same as an eligible ECS/轻量服务器 for obtaining the standard ICP service code. If the website source server is not Alibaba Cloud, file through the source server access provider; OSS custom-domain备案 does not solve the service-code requirement for a non-Alibaba source server.
- Clarified static-site feasibility: static vs dynamic does not determine ICP filing. Filing depends mainly on whether the domain resolves to or uses a mainland China server/cloud resource. A fully static site can avoid buying a VM by using static hosting, but if hosted on mainland resources or mainland CDN/custom domains, ICP filing is still required.
- Added the current lightweight route: use GitHub Pages for the MVP site, optionally store images directly in the Pages repo at first, and move images to object storage/CDN later if image volume or traffic exceeds GitHub Pages' practical limits.
- Clarified GitHub Pages site count: one account can have only one user/organization site such as `<owner>.github.io`, but can have many project sites, one per repository, such as `<owner>.github.io/<repo>/`. Each project site can act as a separate static blog/site.
- Built the initial static GitHub Pages MVP: `index.html`, `styles.css`, `app.js`, `data/current/manifest.json`, optimized map assets, `.nojekyll`, `CNAME`, README, and deployment notes.
- Integrated a real WRF hourly precipitation product sample from `Precip_hourly_WRF_AllRain_T01_T48_InitUTC_2026-07-06_18_00.png` by generating `data/current/maps/wrf_precip_20260706_1800_t01_t48.webp` at 2200x2200 and 476 KB. The original 7000x7000 PNG remains in the workspace but is ignored by Git.
- Initial local HTTP preview used `http://127.0.0.1:5173/` from `python3 -m http.server 5173 --bind 127.0.0.1`.
- Created local initial commit `30504fe Build initial static forecast site`.
- User pushed the repository to GitHub. Local remote is `origin git@github.com:keruicode/iaplacs-site.git`; current branch is `main`, tracking `origin/main`.
- GitHub Pages should be enabled from `Settings -> Pages -> Build and deployment -> Source: Deploy from a branch -> Branch: main -> folder: / (root) -> Save`.
- Added LACS branding assets. The user-provided low-resolution `logo_lacs.png` was copied to `assets/brand/logo-lacs-source.png`; a 4x transparent wordmark backup was generated as `assets/brand/logo-lacs-wordmark@4x.png`; an AI-generated technology-style icon was saved as `assets/brand/logo-lacs-tech-icon.png`; favicon assets were generated; and the website previously used `assets/brand/logo-lacs-lockup@2x.png`.
- Current local preview for the Shangrao update is running at `http://127.0.0.1:5174/` from `python3 -m http.server 5174 --bind 127.0.0.1`.
- GitHub Pages default URL is live at `https://keruicode.github.io/iaplacs-site/` and returned `HTTP/2 200`. The user likely clicked `Remove` for the custom domain; this does not require rebuilding Pages. Re-enter `iaplacs.xyz` in `Settings -> Pages -> Custom domain` and save.
- GitHub Pages now reports `DNS check unsuccessful / NotServedByPagesError` for `iaplacs.xyz`. DNS diagnosis shows authoritative nameservers `dns13.hichina.com` and `dns14.hichina.com`, but no `A` record for `iaplacs.xyz` and no `CNAME/A` record for `www.iaplacs.xyz`. The fix is to add GitHub Pages DNS records in Aliyun DNS.
- User is on the Aliyun domain registration details page showing DNS servers, SSL certificate, ESA, and a cloud-server purchase prompt. For the GitHub Pages route, this is not where to buy a server. Keep DNS servers as `dns13.hichina.com` and `dns14.hichina.com`; go to `云解析 DNS` / `解析设置` to add records instead.
- User shared an Aliyun domain list screenshot. The correct next click is the blue `解析` action on the `iaplacs.xyz` row, not `管理`, not `DNS修改`, and not the cloud-server purchase prompt.
- User shared the Aliyun `快速添加解析` screenshot. For that dialog, select only `iaplacs.xyz` for the IPv4/A-record batch, enter the four GitHub Pages IPs one per line, and do not select `www.iaplacs.xyz` there. Add `www` separately as a CNAME to `keruicode.github.io`.
- User added the four A records for `iaplacs.xyz` successfully. Authoritative DNS at `dns13.hichina.com` now returns the four GitHub Pages IPs for `iaplacs.xyz`; `www.iaplacs.xyz` still has no CNAME/A response. Next step is adding `www` as a CNAME.
- Added the Shangrao service page at `/shangrao/` via `shangrao/index.html`.
- Reworked the header so the LACS organization name is rendered as real HTML text instead of being embedded in a logo image. Both `index.html` and `shangrao/index.html` now use the blue icon plus typed Chinese/English text.
- Generated `assets/brand/logo-lacs-blue-icon.png` from the previous icon by replacing the green/teal component with blue tones, and regenerated favicon assets from that blue icon.
- Pushed content commit `830ebe0 Add Shangrao service page` to `origin/main`.
- Verified the deployed custom-domain pages: `https://iaplacs.xyz/` contains the blue icon, HTML text logo, and Shangrao navigation; `https://iaplacs.xyz/shangrao/` returns the Shangrao service page and WRF sample image references.
- Copied a newly generated WRF 36-panel montage test from the Huan `login02` workflow into `data/current/maps/wrf_montage_20260709_02/`.
- Added `tools/build_forecast_catalog.py`, which scans `data/current/maps/wrf_montage_YYYYMMDD_HH/` and `data/current/maps/worknx_summary_YYYYMMDD_HH/` directories and writes `data/current/forecast-runs.json`.
- Added `data/current/forecast-runs.json` with `main` service runs for WORK_nx `20260709_00` and WRF montage `20260709_02`, plus `shangrao` service run for WRF montage `20260709_02`.
- Reworked `app.js` to support multi-run forecast catalogs, clickable 起报时间, clickable product/image frames, 5-minute no-store refresh, and fallback to the old `manifest.json` if the new catalog is absent.
- Reworked `/shangrao/` from a static image page into a dynamic forecast viewer using the same app code as the homepage with `data-service="shangrao"`.
- Updated README and deployment notes so the server publishing flow runs `python3 tools/build_forecast_catalog.py` after copying montage images and before `git add`.
- Server-side publishing from `login02 -> server02` is now working for the GitHub Pages repo. WRF montage publishing first pushed `60bafcb Update WRF montage 20260709_02`.
- The homepage comprehensive forecast is now published from read-only `/data1/elpt_2022_00083/zhoubj/WORK_nx` by selecting the newest stable `Precip_hourly_WRF_AllRain_T01_T48_InitUTC_*.png` according to the image file generation/modification time (`mtime`), not the WRF `Times` metadata.
- Latest WORK_nx image published by the server script:
  `/data1/elpt_2022_00083/zhoubj/WORK_nx/2026070900/gfs/wrf/Precip_hourly_WRF_AllRain_T01_T48_InitUTC_2026-07-09_00_00.png`, with `mtime=2026-07-09T22:44:07+08:00` and size `5779597` bytes.
- Server-side WORK_nx publishing pushed `770acf8 Update WORK_nx summary 20260709_00`, then follow-up commit `829a334 Update WORK_nx summary 20260709_00` after adding `forecast-runs.json` support.
- Local UI work was rebased onto remote server commits `60bafcb`, `770acf8`, and `829a334`, resolving the `forecast-runs.json` add/add conflict by rerunning `python3 tools/build_forecast_catalog.py`.
- Pushed feature commit `f48c2df Add multi-run forecast catalog` to `origin/main`.
- Deployed online frontend now reads `data/current/forecast-runs.json`; versioned checks confirmed `main_latest=20260709_00` and `shangrao_latest=20260709_02`.
- User reported `/shangrao/` showing the old `无法读取 manifest.json` state. This was traced to stale cached `app.js`/HTML behavior, so `index.html` and `shangrao/index.html` now load versioned `styles.css?v=20260710-02` and `app.js?v=20260710-02`.
- Removed the Play button and station-series blocks from homepage and Shangrao page. The right panel now shows product status, precipitation color scale, and product/service notes instead of fake Beijing/Shangrao station charts.
- Updated `app.js` to cache-bust forecast JSON reads by refresh interval, disable previous/next controls when a product has only one image, and render product notes.
- Updated precipitation legends in `tools/build_forecast_catalog.py` to a stepped precipitation scale with ticks `0, 0.1, 2, 5, 10, 25, 50, 100+`, then regenerated `data/current/forecast-runs.json`.
- Pushed fix commit `e9baec6 Fix Shangrao forecast viewer state` to `origin/main`.
- Verified deployed `/shangrao/?v=e9baec6`, `app.js?v=20260710-02`, and `forecast-runs.json?v=e9baec6`: Shangrao page references versioned CSS/JS, the JS contains `withCacheBuster`, and the online catalog still reports `main_latest=20260709_00`, `shangrao_latest=20260709_02`.
- Reworked the site service structure after user feedback: `/` is now `机场气象服务`, `/ningxia/` is the dedicated `宁夏预报` page for WORK_nx/NX products, and `/shangrao/` remains the dedicated Shangrao WRF service page.
- Added `ningxia/index.html`, updated top navigation across all pages, and moved 起报时间 selection into a horizontal top strip above the main product workspace.
- Updated `tools/build_forecast_catalog.py` to generate separate `airport`, `ningxia`, and `shangrao` service catalogs. `main` remains as a compatibility alias for `airport`; WORK_nx products no longer appear on the homepage or Shangrao page.
- Restored homepage fallback `manifest.json` to airport sample products and removed the old Beijing station-series fallback.
- Updated precipitation, temperature, and wind legends to stepped scales: precipitation ticks `0, 0.1, 1, 5, 10, 25, 50, 100+`; temperature ticks `-20, -10, 0, 10, 20, 30, 40`; wind ticks `0, 2, 5, 8, 12, 17, 25+`.
- Current local preview is running at `http://127.0.0.1:5175/`; `http://127.0.0.1:5174/` is occupied by an older stuck Python listener.
- Local code commit for the service split is `917c4e3 Split airport Ningxia and Shangrao services`.
- Removed all color-scale/legend UI and data config from the site. `index.html`, `ningxia/index.html`, and `shangrao/index.html` no longer contain 色标 blocks; `app.js` no longer renders legends; `tools/build_forecast_catalog.py`, `data/current/forecast-runs.json`, and fallback `manifest.json` no longer emit/store `legend` fields.
- Added a static client-side password gate. All pages start with `body.auth-lock`; `app.js` requires password `123`, then stores `localStorage["iaplacs_access_token"]="iaplacs_access_granted_v1"` so the same browser does not prompt again. This is a lightweight static access gate, not server-grade security.
- Bumped frontend asset query strings to `styles.css?v=20260710-04` and `app.js?v=20260710-04`.
- Local code commit for legend removal and static password gate is `3547fb6 Add static access gate and remove legends`.
- Server publishing retained three Ningxia runs in commits `ddcea51`, `13d90f3`, and `bab4bd3`; the live Ningxia catalog now exposes `20260709_00`, `20260709_06`, and `20260709_12`, labeled `08:00`, `14:00`, and `20:00 BJT`.
- A temporary direct Shangrao WORK scanner was added in `d497951` and published a nationwide Fog/typhoon image in `9169de7`; this was a product-family mistake, not the requested regional WRF montage flow, and has been fully removed.
- Reworked the top run selector into compact date/time buttons with a `最新` marker, run count/latest summary, horizontal mobile scrolling, and a manual refresh control.
- Forecast JSON now refreshes every two minutes with a unique cache-busting query. When a newer run appears during an open session, the viewer switches to it automatically; returning to a visible tab also triggers a refresh.
- Added cache-busting to product image URLs using the run publication timestamp, preventing an updated image at the same path from remaining stale in the browser.
- Added a full-screen image viewer for all three pages. Clicking the main image or `放大查看` opens it; desktop supports wheel/double-click zoom and dragging, while touch devices support double-tap, two-finger pinch zoom, and dragging. The viewer also provides zoom, reset, and close controls and supports `Esc`/keyboard navigation.
- Updated asset query strings to `styles.css?v=20260710-05` and `app.js?v=20260710-05`.
- Corrected deployment guidance so new run directories are merged into `data/current/maps/` rather than deleting `data/current`; removing that directory was the reason only one initial time could remain. Current supported run families are `wrf_montage_*` for Shangrao and `worknx_summary_*` for Ningxia.
- Frontend code commit after rebasing onto the latest server data is `879a975 Improve run switching and image zoom`.
- Pushed the frontend and resume commits through `6b7f403 Update resume for multi-run viewer` to `origin/main` after preserving the concurrent server data commit `9169de7`.
- Verified the deployed homepage, `/ningxia/`, and `/shangrao/` all reference `styles.css?v=20260710-05` and `app.js?v=20260710-05`; the first Ningxia request briefly hit an older Pages cache node, and a retry returned the new page.
- Server-side correction commit `81fc446 Remove incorrect Shangrao WORK product` removed the temporary image, directory, and scanner support. The wrong image URL now returns HTTP 404; Shangrao accepts only `wrf_montage_*` products.
- The corrected `batch_ncks.sh` -> NCL -> montage pipeline then backfilled `20260709_14`, `20260709_20`, and `20260710_02` in commits `13308f3`, `9b62e8c`, and `d7ce6d3`. Together with `20260709_02`, the live Shangrao catalog now has four valid WRF montage runs, each with four frames.
- Changed only the top run-card presentation to chronological order: oldest is on the left and newest is on the right. The underlying newest-first catalog and each card's original array index are preserved, so default/latest selection and product switching remain correct; the active latest card automatically scrolls into view at the right edge.
- Bumped the script query string on all three pages to `app.js?v=20260710-06`. Code commit: `07cac8c Order forecast runs oldest to newest`.
- Pushed the order fix and resume commit through `70a240f Update resume for chronological run order`; verified all three deployed pages load `app.js?v=20260710-06` after Pages cache propagation.
- User then reported that changing initial times left the displayed image unchanged on both Ningxia and Shangrao, and asked to move Shangrao `总览 6x6 / 细节 1/3 / 细节 2/3 / 细节 3/3` controls above the image.
- Diagnosis showed no missing server files: all four Shangrao runs had four distinct, locally decodable frames, and all 16 deployed image URLs returned HTTP 200 with the correct PNG/WebP content type. The three Ningxia files were also distinct and valid.
- The practical browser risk was excessive decoded image size rather than compressed transfer size: Ningxia PNGs were `7000x7000 RGBA` (about 196 MB decoded each); Shangrao overviews were `6168x6168` (about 152 MB decoded), and details were `4112x3084` (about 51 MB decoded). This can leave a mobile browser showing one cached bitmap while later switches fail to decode.
- Reworked image switching to use an explicit request ID and `AbortController`: every new run/frame cancels the previous fetch, clears the old image, fetches the selected URL as a Blob, ignores stale completions, and retries once with a fresh query on failure. The map now shows loading/error state instead of silently retaining the previous image.
- Moved `leadTabs` above `map-stage` on the airport, Ningxia, and Shangrao pages; updated the map grid row order and added `decoding="async"` to forecast images.
- Added executable `tools/optimize_forecast_images.sh`. It creates timestamp-preserving WebP derivatives with ImageMagick, limiting Ningxia and Shangrao overview images to `3200x3200` and Shangrao details to `2800x2100`. Original PNGs remain unchanged.
- Updated `build_ningxia_frames()` to group same-stem PNG/WebP candidates and select the smaller derivative without duplicating frames or losing `valid_time`. WRF frame building already chooses the smallest same-stem candidate.
- Regenerated the current catalog so all three Ningxia frames and all 16 Shangrao frames use optimized WebP. Ningxia images are about 1.0 MB each; Shangrao overviews are about 0.9-1.0 MB and details about 0.4-0.5 MB. Existing product publication timestamps were preserved.
- Removed stale `shangrao_work_*` instructions from README/deployment docs and added the optimizer before catalog generation in the publishing sequence. Bumped all pages to `styles.css?v=20260710-07` and `app.js?v=20260710-07`.
- Code/data commit: `c2667fb Fix forecast image switching and web delivery`.
- Pushed the code/data and resume commits through `930e65c Update resume for forecast image delivery`. After Pages cache propagation, all three deployed pages loaded `v07`, the online catalog used WebP for every Ningxia/Shangrao frame, and all 19 optimized image URLs returned `HTTP 200 image/webp`.

## Important Changed Files

- `/Users/xiaoxiaotu/_01_IAP/Website/IAPLACS_website_step0_plan.md`
- `/Users/xiaoxiaotu/_01_IAP/Website/Codex_resume_iaplacs_website.md`
- `/Users/xiaoxiaotu/_01_IAP/Website/index.html`
- `/Users/xiaoxiaotu/_01_IAP/Website/styles.css`
- `/Users/xiaoxiaotu/_01_IAP/Website/app.js`
- `/Users/xiaoxiaotu/_01_IAP/Website/data/current/manifest.json`
- `/Users/xiaoxiaotu/_01_IAP/Website/data/current/forecast-runs.json`
- `/Users/xiaoxiaotu/_01_IAP/Website/data/current/maps/wrf_precip_20260706_1800_t01_t48.webp`
- `/Users/xiaoxiaotu/_01_IAP/Website/data/current/maps/wrf_montage_20260709_02/`
- `/Users/xiaoxiaotu/_01_IAP/Website/data/current/maps/wrf_montage_20260709_14/`
- `/Users/xiaoxiaotu/_01_IAP/Website/data/current/maps/wrf_montage_20260709_20/`
- `/Users/xiaoxiaotu/_01_IAP/Website/data/current/maps/wrf_montage_20260710_02/`
- `/Users/xiaoxiaotu/_01_IAP/Website/data/current/maps/worknx_summary_20260709_00/`
- `/Users/xiaoxiaotu/_01_IAP/Website/data/current/maps/worknx_summary_20260709_06/`
- `/Users/xiaoxiaotu/_01_IAP/Website/data/current/maps/worknx_summary_20260709_12/`
- `/Users/xiaoxiaotu/_01_IAP/Website/docs/deployment.md`
- `/Users/xiaoxiaotu/_01_IAP/Website/README.md`
- `/Users/xiaoxiaotu/_01_IAP/Website/CNAME`
- `/Users/xiaoxiaotu/_01_IAP/Website/.nojekyll`
- `/Users/xiaoxiaotu/_01_IAP/Website/.gitignore`
- `/Users/xiaoxiaotu/_01_IAP/Website/assets/brand/logo-lacs-lockup@2x.png`
- `/Users/xiaoxiaotu/_01_IAP/Website/assets/brand/logo-lacs-tech-icon.png`
- `/Users/xiaoxiaotu/_01_IAP/Website/assets/brand/logo-lacs-source.png`
- `/Users/xiaoxiaotu/_01_IAP/Website/assets/brand/logo-lacs-wordmark@4x.png`
- `/Users/xiaoxiaotu/_01_IAP/Website/assets/brand/favicon-192.png`
- `/Users/xiaoxiaotu/_01_IAP/Website/assets/brand/favicon-512.png`
- `/Users/xiaoxiaotu/_01_IAP/Website/assets/brand/logo-lacs-blue-icon.png`
- `/Users/xiaoxiaotu/_01_IAP/Website/shangrao/index.html`
- `/Users/xiaoxiaotu/_01_IAP/Website/ningxia/index.html`
- `/Users/xiaoxiaotu/_01_IAP/Website/airpots/index.html`
- `/Users/xiaoxiaotu/_01_IAP/Website/tools/build_forecast_catalog.py`
- `/Users/xiaoxiaotu/_01_IAP/Website/tools/optimize_forecast_images.sh`
- Remote GitHub Pages repo, pushed from `server02`:
  - `data/current/maps/wrf_montage_20260709_02/`
  - `data/current/maps/worknx_summary_20260709_00/`
  - `data/current/manifest.json`
  - `data/current/forecast-runs.json`

## Verification Commands and Results

```bash
pwd
```

Result: `/Users/xiaoxiaotu/_01_IAP/Website`

```bash
ls -la
```

Result at start: empty directory except `.` and `..`. After implementation the site files listed above exist.

```bash
git status --short
```

Result at start: `fatal: not a git repository (or any of the parent directories): .git`

```bash
python3 -m json.tool data/current/manifest.json
```

Result: valid JSON.

```bash
python3 -c 'import json, pathlib; m=json.load(open("data/current/manifest.json")); missing=[]; [missing.append(f["file"]) for p in m["products"] for f in p["frames"] if not pathlib.Path(f["file"].replace("./", "")).exists()]; print("missing=" + str(missing)); raise SystemExit(1 if missing else 0)'
```

Result: `missing=[]`

```bash
NO_PROXY=127.0.0.1,localhost curl -I http://127.0.0.1:5173/
```

Result: `HTTP/1.0 200 OK`

```bash
NO_PROXY=127.0.0.1,localhost curl -I http://127.0.0.1:5173/data/current/maps/wrf_precip_20260706_1800_t01_t48.webp
```

Result: `HTTP/1.0 200 OK`, `Content-Length: 484974`, `Content-type: image/webp`.

```bash
sips -g pixelWidth -g pixelHeight data/current/maps/wrf_precip_20260706_1800_t01_t48.webp
```

Result: `pixelWidth: 2200`, `pixelHeight: 2200`.

```bash
git status --short
```

Result after initial commit: clean.

```bash
NO_PROXY=127.0.0.1,localhost curl -I http://127.0.0.1:5173/assets/brand/logo-lacs-lockup@2x.png
```

Result: `HTTP/1.0 200 OK`, `Content-type: image/png`, `Content-Length: 163935`.

```bash
NO_PROXY=127.0.0.1,localhost curl -s http://127.0.0.1:5173/ | rg -n "logo-lacs-lockup|favicon|IAP-LACS Forecast"
```

Result before the Shangrao update: page references `favicon-192.png`, `favicon-512.png`, and `logo-lacs-lockup@2x.png`.

```bash
NO_PROXY=127.0.0.1,localhost curl -I http://127.0.0.1:5174/
NO_PROXY=127.0.0.1,localhost curl -I http://127.0.0.1:5174/shangrao/
```

Result after the Shangrao update: both returned `HTTP/1.0 200 OK`.

```bash
rg -n "logo-lacs-blue-icon|brand-title|上饶服务" index.html
rg -n "上饶专项天气服务|logo-lacs-blue-icon|wrf_precip" shangrao/index.html
```

Result after the Shangrao update: main page references the blue icon and real header text; Shangrao page references its title, blue icon, and WRF sample image.

```bash
NO_PROXY=127.0.0.1,localhost curl -I http://127.0.0.1:5174/assets/brand/logo-lacs-blue-icon.png
NO_PROXY=127.0.0.1,localhost curl -I http://127.0.0.1:5174/styles.css
NO_PROXY=127.0.0.1,localhost curl -I http://127.0.0.1:5174/data/current/maps/wrf_precip_20260706_1800_t01_t48.webp
```

Result after the Shangrao update: all returned `HTTP/1.0 200 OK`.

```bash
git push
```

Result: pushed `main` to `origin`, including content commit `830ebe0 Add Shangrao service page`.

```bash
NO_PROXY=github.io,keruicode.github.io,iaplacs.xyz curl -I https://iaplacs.xyz/shangrao/
NO_PROXY=github.io,keruicode.github.io,iaplacs.xyz curl -s https://iaplacs.xyz/ | rg -n "logo-lacs-blue-icon|brand-title|上饶服务"
NO_PROXY=github.io,keruicode.github.io,iaplacs.xyz curl -s https://iaplacs.xyz/shangrao/ | rg -n "上饶专项天气服务|logo-lacs-blue-icon|wrf_precip"
```

Result after GitHub Pages deployment: `https://iaplacs.xyz/shangrao/` returned `HTTP/2 200`; live homepage and Shangrao page content matched the new blue-logo/HTML-text/Shangrao implementation.

```bash
python3 tools/build_forecast_catalog.py
```

Result after WRF-only local catalog: `wrote data/current/forecast-runs.json with 1 run(s)`.

After rebasing the server-side WORK_nx commits:

```bash
python3 tools/build_forecast_catalog.py
```

Result: `wrote data/current/forecast-runs.json with 2 main run(s), 1 shangrao run(s)`.

```bash
python3 -m json.tool data/current/forecast-runs.json
node --check app.js
python3 -m py_compile tools/build_forecast_catalog.py
```

Result: all passed.

```bash
python3 - <<'PY'
import json, pathlib
root=pathlib.Path('.')
cat=json.load(open('data/current/forecast-runs.json'))
missing=[]
for svc in cat['services'].values():
    for run in svc['runs']:
        for product in run['products']:
            for frame in product['frames']:
                p=root / frame['file'].replace('./','',1)
                if not p.exists():
                    missing.append(str(p))
print('missing=' + str(missing))
raise SystemExit(1 if missing else 0)
PY
```

Result: `missing=[]`.

```bash
NO_PROXY=127.0.0.1,localhost curl -I http://127.0.0.1:5174/data/current/forecast-runs.json
NO_PROXY=127.0.0.1,localhost curl -s http://127.0.0.1:5174/ | rg -n "forecast-runs|runList|data-service|上饶服务"
NO_PROXY=127.0.0.1,localhost curl -s http://127.0.0.1:5174/shangrao/ | rg -n "forecast-runs|runList|data-service|上饶产品"
NO_PROXY=127.0.0.1,localhost curl -I http://127.0.0.1:5174/data/current/maps/wrf_montage_20260709_02/20260709_02_combined_detail_p01_4x3_grid.webp
```

Result: local preview returned the new catalog, homepage dynamic run selector markers, Shangrao dynamic run selector markers, and the WRF montage image with `HTTP/1.0 200 OK`.

```bash
NO_PROXY=github.io,keruicode.github.io curl -I https://keruicode.github.io/iaplacs-site/
```

Result: `HTTP/2 200`.

```bash
curl -L --max-time 20 -s https://iaplacs.xyz/data/current/manifest.json
```

Result after server-side WORK_nx publish: homepage `precip_24h` points to `./data/current/maps/worknx_summary_20260709_00/Precip_hourly_WRF_AllRain_T01_T48_InitUTC_2026-07-09_00_00.png`; `published_at=2026-07-09T22:44:07+08:00`; the `生成时间` metric is `2026-07-09 22:44:07 BJT`.

```bash
curl -L --max-time 20 -s https://raw.githubusercontent.com/keruicode/iaplacs-site/main/data/current/forecast-runs.json
```

Result after follow-up publish commit `829a334`: `services.main.latest_run=worknx_20260709_00`, `published_at=2026-07-09T22:44:07+08:00`, and the frame file is the same WORK_nx image path.

```bash
curl -L --max-time 20 -I https://iaplacs.xyz/data/current/forecast-runs.json
```

Result after GitHub Pages caught up: `HTTP/2 200`, `content-length: 2783`.

```bash
curl -L --max-time 20 -I https://iaplacs.xyz/data/current/maps/worknx_summary_20260709_00/Precip_hourly_WRF_AllRain_T01_T48_InitUTC_2026-07-09_00_00.png
```

Result: `HTTP/2 200`, `content-length: 5779597`.

```bash
git push
```

Result after rebasing remote server commits: pushed `f48c2df Add multi-run forecast catalog` to `origin/main`.

```bash
NO_PROXY=github.io,keruicode.github.io,iaplacs.xyz curl -s 'https://iaplacs.xyz/data/current/forecast-runs.json?v=f48c2df' -o /tmp/iaplacs_live_forecast_runs.json
python3 - <<'PY'
import json
p='/tmp/iaplacs_live_forecast_runs.json'
print('bytes', len(open(p,'rb').read()))
cat=json.load(open(p))
print('services', list(cat.get('services',{})))
print('main_latest', cat.get('services',{}).get('main',{}).get('latest_run'))
print('shangrao_latest', cat.get('services',{}).get('shangrao',{}).get('latest_run'))
PY
```

Result: `services ['main', 'shangrao']`, `main_latest 20260709_00`, `shangrao_latest 20260709_02`.

```bash
NO_PROXY=github.io,keruicode.github.io,iaplacs.xyz curl -s 'https://iaplacs.xyz/?v=f48c2df' | rg -n "forecast-runs|runList|data-service|上饶服务"
NO_PROXY=github.io,keruicode.github.io,iaplacs.xyz curl -s 'https://iaplacs.xyz/shangrao/?v=f48c2df' | rg -n "forecast-runs|runList|data-service|上饶产品"
NO_PROXY=github.io,keruicode.github.io,iaplacs.xyz curl -I 'https://iaplacs.xyz/data/current/maps/wrf_montage_20260709_02/20260709_02_combined_detail_p01_4x3_grid.webp?v=f48c2df'
NO_PROXY=github.io,keruicode.github.io,iaplacs.xyz curl --max-time 10 -L -r 0-0 -o /tmp/iaplacs_worknx_byte.bin -w 'http=%{http_code} size=%{size_download}\n' 'https://iaplacs.xyz/data/current/maps/worknx_summary_20260709_00/Precip_hourly_WRF_AllRain_T01_T48_InitUTC_2026-07-09_00_00.png?v=f48c2df'
```

Result: homepage and Shangrao dynamic markup found; WRF WebP returned `HTTP/2 200`; WORK_nx range request returned `http=206 size=1`.

```bash
node --check app.js
python3 -m py_compile tools/build_forecast_catalog.py
python3 -m json.tool data/current/forecast-runs.json
```

Result after cache/UI cleanup: all passed.

```bash
rg -n "playToggle|播放|站点序列|stationChart|station-block" index.html shangrao/index.html app.js styles.css
```

Result after cleanup: no matches.

```bash
NO_PROXY=127.0.0.1,localhost curl -s http://127.0.0.1:5174/shangrao/ | rg -n "app.js\?v=20260710-02|styles.css\?v=20260710-02|productNote|forecast-runs|上饶产品"
NO_PROXY=127.0.0.1,localhost curl -s http://127.0.0.1:5174/ | rg -n "app.js\?v=20260710-02|styles.css\?v=20260710-02|productNote|forecast-runs|产品状态"
NO_PROXY=127.0.0.1,localhost curl -s 'http://127.0.0.1:5174/data/current/forecast-runs.json?v=test' -o /tmp/iaplacs_local_forecast_runs.json
```

Result: local homepage and Shangrao page reference versioned assets and `forecast-runs.json`; local catalog parses with `main_latest=20260709_00`, `shangrao_latest=20260709_02`, and stepped precipitation ticks `['0', '0.1', '2', '5', '10', '25', '50', '100+']`.

```bash
git push
```

Result: pushed `e9baec6 Fix Shangrao forecast viewer state` to `origin/main`.

```bash
NO_PROXY=github.io,keruicode.github.io,iaplacs.xyz curl -s 'https://iaplacs.xyz/shangrao/?v=e9baec6' | rg -n "app.js\?v=20260710-02|styles.css\?v=20260710-02|productNote|forecast-runs|上饶产品|播放|站点序列"
NO_PROXY=github.io,keruicode.github.io,iaplacs.xyz curl -s 'https://iaplacs.xyz/app.js?v=20260710-02' | rg -n "withCacheBuster|productNote|playToggle|stationChart|无法读取预报清单"
NO_PROXY=github.io,keruicode.github.io,iaplacs.xyz curl -s 'https://iaplacs.xyz/data/current/forecast-runs.json?v=e9baec6' -o /tmp/iaplacs_live_runs_e9baec6.json
```

Result: online Shangrao HTML references versioned CSS/JS and product notes; online app JS contains `withCacheBuster` and `productNote` with no `playToggle`/`stationChart`; online catalog reports `main_latest=20260709_00`, `shangrao_latest=20260709_02`, and stepped precipitation ticks `['0', '0.1', '2', '5', '10', '25', '50', '100+']`.

```bash
python3 tools/build_forecast_catalog.py
```

Result after airport/Ningxia/Shangrao split: `wrote data/current/forecast-runs.json with 1 airport run(s), 1 ningxia run(s), 1 shangrao run(s)`.

```bash
node --check app.js
python3 -m py_compile tools/build_forecast_catalog.py
python3 -m json.tool data/current/forecast-runs.json
python3 -m json.tool data/current/manifest.json
```

Result after service split: all passed.

```bash
node - <<'NODE'
const fs=require('fs');
const cat=JSON.parse(fs.readFileSync('data/current/forecast-runs.json','utf8'));
const missing=[];
for (const [svcName, svc] of Object.entries(cat.services || {})) {
  for (const run of svc.runs || []) {
    for (const product of run.products || []) {
      for (const frame of product.frames || []) {
        const file=frame.file?.replace(/^\.\/?/,'');
        if (!file || !fs.existsSync(file)) missing.push(`${svcName}/${run.id}/${product.id}: ${frame.file}`);
      }
    }
  }
}
console.log(`services=${Object.keys(cat.services).join(',')}`);
console.log(`airport_products=${cat.services.airport.runs[0].products.map(p=>p.id).join(',')}`);
console.log(`ningxia_products=${cat.services.ningxia.runs[0].products.map(p=>p.id).join(',')}`);
console.log(`shangrao_products=${cat.services.shangrao.runs[0].products.map(p=>p.id).join(',')}`);
console.log(`missing=${JSON.stringify(missing)}`);
process.exit(missing.length ? 1 : 0);
NODE
```

Result: `services=airport,main,ningxia,shangrao`; `airport_products=airport_precip,airport_temperature,airport_wind`; `ningxia_products=ningxia_precip_series`; `shangrao_products=wrf_rain_montage`; `missing=[]`.

```bash
/bin/zsh -lc "NO_PROXY=127.0.0.1,localhost curl -I http://127.0.0.1:5175/"
/bin/zsh -lc "NO_PROXY=127.0.0.1,localhost curl -I http://127.0.0.1:5175/ningxia/"
/bin/zsh -lc "NO_PROXY=127.0.0.1,localhost curl -I http://127.0.0.1:5175/shangrao/"
```

Result: all three local preview pages returned `HTTP/1.0 200 OK`.

```bash
rg -n "色标|legend|legendUnit|legendBar|legendTicks|renderLegend|20260710-03" index.html ningxia/index.html shangrao/index.html app.js styles.css tools/build_forecast_catalog.py data/current/manifest.json data/current/forecast-runs.json
node --check app.js
python3 -m py_compile tools/build_forecast_catalog.py
python3 -m json.tool data/current/forecast-runs.json
python3 -m json.tool data/current/manifest.json
```

Result after password/legend cleanup: keyword search returned no matches; JS syntax, Python compile, and both JSON checks passed.

```bash
/bin/zsh -lc "NO_PROXY=127.0.0.1,localhost curl -s http://127.0.0.1:5175/ | rg -n 'auth-lock|app.js\\?v=20260710-04|styles.css\\?v=20260710-04|色标|legend'"
/bin/zsh -lc "NO_PROXY=127.0.0.1,localhost curl -s http://127.0.0.1:5175/ningxia/ | rg -n 'auth-lock|app.js\\?v=20260710-04|styles.css\\?v=20260710-04|色标|legend'"
/bin/zsh -lc "NO_PROXY=127.0.0.1,localhost curl -s http://127.0.0.1:5175/shangrao/ | rg -n 'auth-lock|app.js\\?v=20260710-04|styles.css\\?v=20260710-04|色标|legend'"
```

Result: all three pages contain `auth-lock`, reference `20260710-04` CSS/JS, and have no `色标`/`legend` matches.

```bash
node - <<'NODE'
const fs=require('fs');
const catalog=JSON.parse(fs.readFileSync('data/current/forecast-runs.json','utf8'));
const fallback=JSON.parse(fs.readFileSync('data/current/manifest.json','utf8'));
function countLegend(value){
  let count=0;
  function walk(v){
    if (!v || typeof v !== 'object') return;
    if (Object.prototype.hasOwnProperty.call(v, 'legend')) count += 1;
    for (const child of Object.values(v)) walk(child);
  }
  walk(value);
  return count;
}
console.log(`catalog_legend=${countLegend(catalog)}`);
console.log(`manifest_legend=${countLegend(fallback)}`);
console.log(`services=${Object.keys(catalog.services).join(',')}`);
NODE
```

Result: `catalog_legend=0`, `manifest_legend=0`, `services=airport,main,ningxia,shangrao`.

```bash
dig +short iaplacs.xyz A
dig +short www.iaplacs.xyz CNAME
dig +short www.iaplacs.xyz A
```

Result: empty output for all three.

```bash
dig +short iaplacs.xyz NS
```

Result: `dns13.hichina.com`, `dns14.hichina.com`.

```bash
dig +short @dns13.hichina.com iaplacs.xyz A
```

Result: `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`.

```bash
dig +short @dns13.hichina.com www.iaplacs.xyz CNAME
dig +short @dns13.hichina.com www.iaplacs.xyz A
```

Result: empty output.

```bash
python3 -c '<temporary catalog fixture creating three Ningxia and three Shangrao run directories>'
```

Result: the generated catalog reported `3 ningxia run(s), 3 shangrao run(s)`; Ningxia IDs were sorted `20260710_00,20260709_12,20260709_00`, and Shangrao IDs were sorted `20260710_02,20260709_14,20260709_02`, with the newest ID selected as `latest_run` for each service.

```bash
node --check app.js
python3 -m py_compile tools/build_forecast_catalog.py
python3 -m json.tool data/current/forecast-runs.json
git diff --check
```

Result after the responsive viewer/run-selector update: all checks passed.

```bash
python3 -c '<HTML parser duplicate-ID and required-control check>'
```

Result: `index.html`, `ningxia/index.html`, and `shangrao/index.html` all had `duplicate_ids=[]` and no missing `runSummary`, `refreshCatalog`, `runList`, `forecastImage`, or `imageLink` IDs.

```bash
curl --noproxy 127.0.0.1 -sS http://127.0.0.1:5175/
curl --noproxy 127.0.0.1 -sS http://127.0.0.1:5175/ningxia/
curl --noproxy 127.0.0.1 -sS http://127.0.0.1:5175/shangrao/
```

Result: all pages returned successfully and referenced the `20260710-05` assets, top refresh/run-summary controls, and `放大查看`; local JS/CSS contained the full-screen viewer, pinch handler, two-minute refresh, mobile viewport rules, and `最新` run styling.

```bash
curl --noproxy iaplacs.xyz -L -sS 'https://iaplacs.xyz/data/current/forecast-runs.json?inspect=20260710-1129'
```

Result before pushing the frontend commit: the deployed catalog already exposed Ningxia runs `20260709_12,20260709_06,20260709_00` and Shangrao runs `20260710_02,20260709_02`, proving the server-side multi-run data publishing was live.

```bash
git push origin main
```

Result: pushed `9169de7..6b7f403` to `origin/main`, including frontend commit `879a975` and the resume update.

```bash
curl --noproxy iaplacs.xyz -L -sS 'https://iaplacs.xyz/?deploy=6b7f403'
curl --noproxy iaplacs.xyz -L -sS 'https://iaplacs.xyz/ningxia/?deploy=6b7f403-retry1'
curl --noproxy iaplacs.xyz -L -sS 'https://iaplacs.xyz/shangrao/?deploy=6b7f403'
curl --noproxy iaplacs.xyz -L -sS 'https://iaplacs.xyz/app.js?v=20260710-05-deploy-6b7f403'
curl --noproxy iaplacs.xyz -L -sS 'https://iaplacs.xyz/data/current/forecast-runs.json?deploy=6b7f403'
```

Result: all three deployed pages returned the `20260710-05` controls and `放大查看`; deployed JS contained `setupImageViewer`, `createPinchGesture`, `withAssetVersion`, and the two-minute refresh; the online catalog parsed with Ningxia IDs `20260709_12,20260709_06,20260709_00` and Shangrao IDs `20260710_02,20260709_02`.

Later server correction: commit `81fc446` removed the invalid `20260710_02` Shangrao WORK directory and scanner. Slurm job `38120551` then generated the missing regional mosaics, and commits `13308f3`, `9b62e8c`, and `d7ce6d3` deployed the valid `20260709_14`, `20260709_20`, and `20260710_02` runs.

```bash
node --check app.js
node -e '<render-order fixture>'
git diff --check
```

Result for the run-order change: JS syntax and diff checks passed; the fixture produced `display=old,middle,new`, original indices `2,1,0`, and placed the latest run at display position `2` while retaining original index `0`.

```bash
curl --noproxy 127.0.0.1 -sS http://127.0.0.1:5175/
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:5175/app.js?v=20260710-06'
```

Result: local HTML references `app.js?v=20260710-06`; the served script contains the reversed display list and `displayRuns` renderer.

```bash
git push origin main
curl --noproxy iaplacs.xyz -L -sS 'https://iaplacs.xyz/?order=70a240f'
curl --noproxy iaplacs.xyz -L -sS 'https://iaplacs.xyz/ningxia/?order=70a240f-retry1'
curl --noproxy iaplacs.xyz -L -sS 'https://iaplacs.xyz/shangrao/?order=70a240f-retry1'
curl --noproxy iaplacs.xyz -L -sS 'https://iaplacs.xyz/app.js?v=20260710-06-order-70a240f'
```

Result: pushed `81fc446..70a240f`; all deployed pages reference `app.js?v=20260710-06`, and the deployed script contains `displayRuns` plus `.reverse()`. The live catalog at verification time retained three Ningxia runs and one valid Shangrao run.

```bash
file data/current/maps/wrf_montage_*/*_grid.png
file data/current/maps/worknx_summary_*/*.png
curl --noproxy iaplacs.xyz -I '<each of the 16 Shangrao frame URLs>'
```

Result during image-switch diagnosis: all local source images were valid; all 16 deployed Shangrao URLs returned HTTP 200 with correct image types. The source dimensions were `7000x7000` for Ningxia, `6168x6168` for Shangrao overviews, and `4112x3084` for Shangrao details.

```bash
IAPLACS_OPTIMIZE_FORCE=1 tools/optimize_forecast_images.sh
python3 tools/build_forecast_catalog.py
bash -n tools/optimize_forecast_images.sh
node --check app.js
python3 -m py_compile tools/build_forecast_catalog.py
python3 -m json.tool data/current/forecast-runs.json
git diff --check
```

Result: generated three `3200x3200` Ningxia WebPs, four `3200x3200` Shangrao overview WebPs, and twelve `2800x2100` detail WebPs. All checks passed; a second optimizer run produced no output, confirming unchanged derivatives are skipped.

```bash
curl --noproxy 127.0.0.1 -sS http://127.0.0.1:5175/ningxia/
curl --noproxy 127.0.0.1 -sS http://127.0.0.1:5175/shangrao/
curl --noproxy 127.0.0.1 -I '<one optimized Ningxia WebP>'
curl --noproxy 127.0.0.1 -I '<one optimized Shangrao WebP>'
```

Result: both pages referenced `20260710-07`; `leadTabs` appeared before `map-stage`; optimized files returned HTTP 200 as `image/webp`; the local catalog used WebP for every Ningxia and Shangrao frame.

```bash
git push origin main
curl --noproxy iaplacs.xyz -L -sS 'https://iaplacs.xyz/?images=930e65c-retry1'
curl --noproxy iaplacs.xyz -L -sS 'https://iaplacs.xyz/ningxia/?images=930e65c-retry1'
curl --noproxy iaplacs.xyz -L -sS 'https://iaplacs.xyz/shangrao/?images=930e65c'
curl --noproxy iaplacs.xyz -L -sS 'https://iaplacs.xyz/app.js?v=20260710-07-images-930e65c'
curl --noproxy iaplacs.xyz -I '<each optimized catalog image URL>'
```

Result: pushed `e167bd7..930e65c`; all pages loaded `20260710-07`, controls were above the image, deployed JS contained cancellation/Blob/retry switching, and all 19 optimized Ningxia/Shangrao WebPs returned `200 image/webp`.

Official references checked during planning:

- Alibaba Cloud DNS add-record documentation.
- Alibaba Cloud ICP filing service page.
- National public security internet filing portal.
- Certbot Nginx instructions.
- GitHub Pages quickstart and publishing-source docs.

## Current OSS-First Image Delivery And Five-Run Retention

- The production asset origin is `https://iaplacs-forecast-images-hk.oss-cn-hongkong.aliyuncs.com/iaplacs/`. GitHub Pages carries the HTML/JS/catalog; Ningxia and Shangrao forecast frames in the catalog point to OSS, while airport sample SVGs remain GitHub-relative.
- `tools/build_forecast_catalog.py` now defaults `IAPLACS_ASSET_BASE_URL` to the production OSS prefix and defaults `IAPLACS_MAX_RUNS` to `5`. An explicit empty `IAPLACS_ASSET_BASE_URL` can still be used for a deliberate GitHub-relative fallback build.
- The server-side publishers in `/Volumes/storage/江西VPN-每日预报` create proportional WebP derivatives with no crop operation, upload PNG/WebP assets to OSS, verify a public object, and then build/push the OSS-backed catalog. GitHub image copies remain as a fallback.
- OSS retention is active at five initialization times separately for `worknx_summary_*` and `wrf_montage_*`; the Bucket inventory after cleanup was 50 forecast objects (five Ningxia runs with PNG/WebP plus five Shangrao runs with four PNG/WebP frames).
- Frontend `app.js` now limits every normalized service catalog to five runs as a second guard, preserving the existing display order of oldest on the left and newest on the right.
- Local repository was fast-forwarded from `8ed8620` to server-published `67defd0 Update WORK_nx summary 20260710_00`. The current catalog reports five Ningxia runs (`20260710_00` through `20260709_00`), five Shangrao runs (`20260710_08` through `20260709_02`), 25 forecast frame URLs, and all 25 use the OSS host.
- Measured from the same Mac, OSS delivery was materially faster than GitHub for the tested products: Ningxia `0.230s` TTFB / `0.955s` total versus GitHub `2.028s` / `9.767s`; Shangrao `0.198s` / `0.525s` versus `0.504s` / `4.806s`.
- `server02` has user-local `~/bin/ossutil` v1.7.19 installed from Alibaba Cloud's official current Linux AMD64 package. No OSS credentials were configured or stored by Codex.
- `/Volumes/storage/江西VPN-每日预报/configure_oss_server02.sh` is the interactive one-time setup helper. It keeps AccessKey input inside the server terminal, supports a dedicated CORS rule for `https://iaplacs.xyz`, uploads one isolated WebP test object, verifies public range access and the CORS response, and only then enables the runtime environment file.
- The current frontend fetches forecast images as Blobs, so OSS must return `Access-Control-Allow-Origin: https://iaplacs.xyz`; a URL that merely opens in a browser is not sufficient.
- Do not put AccessKey ID/Secret in Git, chat, publisher scripts, cron, or `forecast-runs.json`. Prefer a dedicated RAM user restricted to the selected Bucket/prefix.

## Latest Website Verification

- Website commit `46f06c7 Prefer OSS and retain five forecast runs` was pushed from `67defd0` to `origin/main`; the local worktree is clean and tracks `origin/main`.
- `node --check app.js`, `python3 -m json.tool data/current/forecast-runs.json`, and the catalog-module check all passed. The generator reports `MAX_RUNS=5` and the production OSS prefix by default.
- Live `https://iaplacs.xyz/data/current/forecast-runs.json` verification returned five Ningxia runs (`20260710_00`, `20260709_18`, `20260709_12`, `20260709_06`, `20260709_00`) and five Shangrao runs (`20260710_08`, `20260710_02`, `20260709_20`, `20260709_14`, `20260709_02`). It contains 25 forecast frame URLs: 25 OSS URLs and zero relative forecast URLs.
- Live `/`, `/ningxia/`, and `/shangrao/` HTML all load `app.js?v=20260710-08`; the deployed script contains `MAX_DISPLAY_RUNS = 5` and `limitCatalogRuns`.
- A representative current Ningxia OSS object returned `HTTP 200`, `Content-Type: image/webp`, `Access-Control-Allow-Origin: https://iaplacs.xyz`, `Cache-Control: public,max-age=604800`, and `Content-Length: 3461871`.
- The OSS five-run retention result remains the server-side Bucket inventory of 50 forecast objects. The next operational check is after the next automated Ningxia and Shangrao publication, confirming new objects are uploaded/skipped correctly and old prefixes are pruned without deleting one of the five retained runs.

## Browser Image Preload And Full-Screen Navigation

- The working tree now adds a versioned browser Cache Storage (`iaplacs-forecast-images-v1`) plus an in-memory Blob/Object URL cache. The active service is preloaded across all retained runs with three concurrent image requests; unchanged URLs can be reused after a page reload, while the catalog publication version changes the cache key for a newly published image.
- Expected preload sizes from the current catalog are five images for Ningxia and 20 images for Shangrao. The viewer sequence spans the full active service, so its left/right arrows, keyboard left/right keys, and unzoomed touch swipes can move through all retained runs and product frames without returning to the page controls. The current zoom transform is preserved when navigating with the viewer arrows.
- All three pages now reference `app.js?v=20260710-09`. `node --check app.js`, `git diff --check`, local HTTP `200` checks, and static presence checks for the cache/preload/viewer controls passed.
- Browser automation could not be completed because the available browser list returned `[]`; a real mobile touch pass remains a follow-up after deployment. The implementation falls back to ordinary fetch/memory caching when Cache Storage is unavailable.

## Current Route Layout

- The root `https://iaplacs.xyz/` now uses `data-service="ningxia"` and displays the Ningxia forecast service.
- The previous airport page was moved to `https://iaplacs.xyz/airpots/` in `airpots/index.html`, with parent-relative asset, catalog, and script paths and `data-service="airport"`.
- `/ningxia/` remains available as the dedicated Ningxia route; `/shangrao/` remains the dedicated Shangrao route.
- The visible `机场服务`, `宁夏预报`, and `上饶服务` site-navigation buttons were removed from all four page templates. Internal run-time and product-image controls remain.
- All four templates use `styles.css?v=20260710-08` and `app.js?v=20260710-09`.
- The final route/data-preservation commit is `af7ae1b Make Ningxia the home route and preserve forecast data`, based directly on the latest server-published remote commit `bdd7b42`; it was pushed without force-updating `main`, so the current server forecast tree was retained.
- GitHub tree checks at `af7ae1b` confirmed `index.html` uses `data-service="ningxia"`, `airpots/index.html` uses `data-service="airport"`, and all four templates have no visible `site-nav`/`nav-link` buttons.
- After Pages propagation, live checks returned the root as Ningxia, `/airpots/` as the airport page, and `/ningxia/` plus `/shangrao/` as their existing services. All four live pages loaded CSS v08 and app JS v09.
- Live `forecast-runs.json` remained OSS-first with the bounded five-run catalogs for Ningxia and Shangrao; the latest server publication timestamp observed was `2026-07-11T22:55:04+08:00`.

## Ningxia Page UI Cleanup

- Root `/` and `/ningxia/` were cleaned up for the Ningxia forecast view.
- The left panel no longer shows `当前起报` or `发布时间`. It keeps the `服务说明` label but leaves the content blank, so the generated WORK_nx explanatory note is not displayed on the page.
- The right `服务区域` module position is preserved as an empty block; visible `服务区域 / Ningxia` text and the product-note paragraph were removed on the Ningxia templates.
- The main image badge was removed from the Ningxia templates, and `app.js` also blanks Ningxia `validTime` text. For single-frame Ningxia products, the `T01-T48` lead tab is hidden.
- The image viewer no longer has desktop double-click or mobile double-tap zoom behavior. Button zoom, wheel zoom, pinch zoom, drag, keyboard, and left/right image navigation remain.
- Viewer left/right buttons were enlarged and moved inward from the screen edge on desktop; mobile buttons are also larger than before but remain closer to the sides to preserve image space.
- Root `index.html` now includes a local initial image source, `./data/current/maps/wrf_precip_20260706_1800_t01_t48.webp`, so directly opening the local file or serving it before catalog load still displays one image.
- Root and `/ningxia/` now load `styles.css?v=20260712-01` and `app.js?v=20260712-01`.
- Current local verification passed:
  - `node --check app.js`
  - `git diff --check`
  - `python3 -m json.tool data/current/forecast-runs.json`
  - `rg` confirmed root and `/ningxia/` no longer contain visible `当前起报`, `发布时间`, `T01-T48`, `宁夏页面集中展示`, or `新起报时次` text.
  - Local HTTP checks on `http://127.0.0.1:5180/`, `http://127.0.0.1:5180/ningxia/`, and `http://127.0.0.1:5180/data/current/maps/wrf_precip_20260706_1800_t01_t48.webp` all returned `200`.
- Site-runtime deployment commit `def19ea Clean Ningxia forecast page UI` was built as a fast-forward commit directly on remote `main` commit `7d695fe` using a temporary Git index, so server-published forecast data was preserved. Later resume-only commits may advance `main` without changing runtime site files.
- Live verification after deploy passed:
  - The runtime site files are from `def19ea922f498647ef6f19b84f78b04e6e79d2e`; resume-only follow-up commits `b1a8dc9d0f0dfe506bd0895489fe66fcc4ca69f1` and `efb6be07fa751a753cdbb0a146bc0005cdebd1c6` were also pushed.
  - `https://iaplacs.xyz/?v=def19ea` and `https://iaplacs.xyz/ningxia/?v=def19ea` both load `styles.css?v=20260712-01` and `app.js?v=20260712-01`, include the local initial WebP image, include the empty service-area block, and no longer match the removed visible labels.
  - Live `https://iaplacs.xyz/app.js?v=20260712-01` contains `hideSingleNingxiaFrame` and no `dblclick`, `handleViewerDoubleClick`, or `toggleViewerZoom` matches.
  - Live `https://iaplacs.xyz/styles.css?v=20260712-01` contains the larger inward viewer navigation buttons.
  - Live `https://iaplacs.xyz/data/current/maps/wrf_precip_20260706_1800_t01_t48.webp` returned `HTTP/2 200`, `Content-Type: image/webp`, and `Content-Length: 484974`.
- Important: local `main` is still behind the server-published remote forecast-data history and the working tree shows data-only changes/deletions from concurrent server updates. Do not stage or overwrite `data/current` from this local checkout when publishing UI-only changes.

## Shangrao Frame Label And Layout Fix

- Site-runtime commit `7555ecf Fix Shangrao frame labels and layout` was pushed to `origin/main`, based directly on server-published remote commit `aa3c3c3`, so current forecast data was preserved.
- Root `/` and `/ningxia/` keep the `服务区域` visible label inside the otherwise empty service-area block.
- All four HTML entry points now load `styles.css?v=20260712-02` and `app.js?v=20260712-02`.
- `styles.css` makes `#forecastImage` use the full available width (`width: 100%; max-width: none; max-height: none`) and hides `.map-badge`, so the lower-left `细节 1/3 / T13-T24` style box no longer appears.
- `app.js` now normalizes Shangrao service runs on load:
  - duplicate overview frames are collapsed to one frame, preferring 6x6 WebP when both 6x4 and 6x6 exist;
  - overview tabs are labeled `总览`;
  - detail tabs are labeled by Beijing-time 12-hour windows, such as `07-11 08-20` and `07-11 20-08`;
  - `20260710_02` is pinned back into Shangrao as a historical supplemental run if the five-run live catalog no longer contains it.
- The pinned `20260710_02` Shangrao run uses GitHub Pages relative image URLs because its OSS object check returned `403 Forbidden`, while the GitHub Pages WebP URL returned `HTTP 200`.
- `tools/build_forecast_catalog.py` now applies the same Shangrao overview de-duplication and time-window label rules when the server regenerates `forecast-runs.json`; pinned Shangrao runs force relative URLs instead of OSS URLs.
- Verification passed:
  - `node --check app.js`
  - `python3 -m py_compile tools/build_forecast_catalog.py`
  - `git diff --check`
  - direct Python checks showed `20260710_20` detail labels as `07-11 08-20`, `07-11 20-08`, `07-12 08-20`, and `20260711_08` detail labels as `07-11 20-08`, `07-12 08-20`, `07-12 20-08`.
  - A Node normalization test using live `forecast-runs.json` produced six Shangrao runs: `20260711_20`, `20260711_14`, `20260711_08`, `20260711_02`, `20260710_20`, and pinned `20260710_02`; `20260711_02` had four frames after duplicate overview collapse.
  - Live `https://iaplacs.xyz/?v=7555ecf2` and `https://iaplacs.xyz/shangrao/?v=7555ecf2` both loaded the `20260712-02` assets after Pages cache propagation.
  - Live `https://iaplacs.xyz/app.js?v=20260712-02-7555ecf` contains `SHANGRAO_PINNED_RUN_IDS`, `normalizeShangraoRuns`, and `formatShangraoWindow`, with no `dblclick`/`handleViewerDoubleClick` match.
  - Live `https://iaplacs.xyz/styles.css?v=20260712-02-7555ecf` contains the full-width image and hidden badge rules.

## Ningxia OSS ACL And Shangrao Five-Run Cleanup

- Follow-up thread: `019f54bd-2333-7323-a89d-92bf699aec95`.
- User reported on 2026-07-12 that the Ningxia `2026-07-10 08:00 BJT` precipitation image did not appear, Shangrao showed 6 initial times instead of 5, and the Shangrao page should remove the left-side `当前起报` / `发布时间` / `服务说明` blocks plus the right-side `服务区域` block.
- Live catalog check showed Ningxia had exactly five runs, including `20260710_00` labeled `2026-07-10 08:00 BJT`, and its frame URL was:
  `https://iaplacs-forecast-images-hk.oss-cn-hongkong.aliyuncs.com/iaplacs/data/current/maps/worknx_summary_20260710_00/Precip_hourly_WRF_AllRain_T01_T48_InitUTC_2026-07-10_00_00.webp`.
- Public HEAD check for that `20260710_00` OSS object returned `HTTP/1.1 403 Forbidden` with OSS `AccessDenied` and message `You have no right to access this object because of bucket acl.`
- Public HEAD checks for newer retained objects such as `worknx_summary_20260711_18/...webp`, `worknx_summary_20260711_00/...webp`, and `wrf_montage_20260712_02/...webp` returned `HTTP/1.1 200 OK`. This isolates the Ningxia `20260710_00` problem to old object ACL/public-read state, not a missing catalog entry or whole-bucket outage.
- IAP `login02` was reachable at `10.64.201.2`; `~/bin/ossutil`, `~/.iaplacs-oss.env`, `~/bin/prune_iaplacs_oss.sh`, and `~/iaplacs-site` exist. `ossutil help set-acl` confirmed `ossutil set-acl oss://bucket/object public-read` is supported. Remote `ossutil stat` checks hung and were interrupted, so no remote ACL mutation was performed in this turn.
- Likely publishing root cause: both publisher scripts use `ossutil cp ... -u --acl public-read`. If an old object already exists, `-u` skips upload and may not repair ACL. Early objects uploaded before public ACL setup can remain private while the catalog still references them.
- Live Shangrao catalog showed six runs: `20260712_02`, `20260711_20`, `20260711_14`, `20260711_08`, `20260711_02`, and pinned/relative `20260710_02`.
- Frontend root cause for the sixth Shangrao run: `app.js` pinned `20260710_02` through `SHANGRAO_PINNED_RUN_IDS`, adding it back after slicing to five. Generator root cause: `tools/build_forecast_catalog.py` had the same `SHANGRAO_PINNED_RUN_IDS` logic and forced that run to relative GitHub Pages URLs.
- Local code changes in this follow-up:
  - `app.js`: removed `SHANGRAO_PINNED_RUN_IDS`, removed `createPinnedShangraoRun`, and made `normalizeShangraoRuns()` strictly normalize/slice/sort at `MAX_DISPLAY_RUNS=5`.
  - `tools/build_forecast_catalog.py`: removed Shangrao pinned-run retention and removed `force_relative`; generated Shangrao catalog will now return only latest `MAX_RUNS` runs.
  - `shangrao/index.html`: removed `当前起报`, `发布时间`, `服务说明`, and `服务区域` UI blocks.
  - `index.html`, `ningxia/index.html`, `shangrao/index.html`, and `airpots/index.html`: bumped shared app query string to `app.js?v=20260712-03`.
- Verification passed:
  - `node --check app.js`
  - `PYTHONPYCACHEPREFIX=.tmp/pycache python3 -m py_compile tools/build_forecast_catalog.py`
  - `rg` found no `SHANGRAO_PINNED_RUN_IDS`, `createPinnedShangraoRun`, `force_relative`, `当前起报`, `发布时间`, `服务说明`, or `服务区域` in `app.js`, `tools/build_forecast_catalog.py`, and `shangrao/index.html`.
  - Python check against live catalog showed `live_catalog_shangrao=6` but `frontend_after_slice=5`, keeping `['20260712_02', '20260711_20', '20260711_14', '20260711_08', '20260711_02']`.
  - Local preview started at `http://127.0.0.1:5181/`; `curl --noproxy 127.0.0.1 -I -s http://127.0.0.1:5181/shangrao/` returned `HTTP/1.0 200 OK`, and `curl --noproxy 127.0.0.1 -I -s 'http://127.0.0.1:5181/app.js?v=20260712-03'` returned `HTTP/1.0 200 OK`.
- Working-tree caution: local `main` is still ahead/behind remote and has many pre-existing data changes/deletions from server-published forecast updates. Do not stage `data/current` blindly from this local checkout.

## Known Pitfalls

- If the target server is in mainland China and `iaplacs.xyz` resolves to it, ICP filing is required before normal public access.
- If the IAP server is an internal research/data machine, avoid exposing it directly. Prefer a public Web gateway/ECS and scheduled data push.
- In Alibaba Cloud ICP filing, do not confuse `主体所在地` with the server IP location. `主体所在地` should follow the organizer's real certificate/address. A Beijing server/IP only affects server/access information.
- Owning the domain at Alibaba Cloud/万网 does not by itself provide an Alibaba Cloud ICP service code. The service code comes from an eligible Alibaba Cloud mainland server/resource.
- Alibaba Cloud docs state same-account filing generally auto-generates the service code during filing; different account filing requires service-code authorization from the server owner account, and personal-authenticated accounts cannot authorize service codes to others.
- If the project represents IAP/LACS research data or public forecast services, avoid presenting it as a purely personal website unless the content is genuinely personal. Domain holder, filing主体, website name, and actual content should match.
- Alibaba Cloud OSS documentation says both the website domain resolving to a mainland server and an OSS-bound custom domain used for static files need ICP filing; if the source site is not on Alibaba Cloud, the source server access provider handles the filing and Alibaba Cloud access is not mandatory.
- Static hosting can satisfy an MVP forecast-display site if all products are pre-rendered to Web-friendly files such as manifest JSON, images, tiles, and compressed JSON, then uploaded on a schedule. It becomes insufficient only when the site needs authenticated users, server-side computation, heavy querying, or real-time APIs.
- GitHub Pages official limits as checked on 2026-07-09: source repository recommended limit 1 GB, published site no larger than 1 GB, soft bandwidth limit 100 GB/month, and rate limiting may apply. This is acceptable for a low-traffic image-based MVP but not for heavy public image distribution.
- GitHub Pages official docs as checked on 2026-07-09: maximum one user/organization Pages site per account and maximum one project Pages site per repository.
- GitHub Pages publishing source docs say for branch-based publishing, select `Deploy from a branch`, then choose the branch and source folder; for this repository that is `main` and `/`.
- Do not send raw large NetCDF/GRIB/MICAPS files directly to browsers. Generate Web-friendly manifests, images, tiles, GeoJSON, or compressed JSON.
- Compressed file size alone is not a sufficient browser-performance check. A 5-6 MB `7000x7000 RGBA` PNG expands to roughly 196 MB when decoded; several such images can prevent mobile run switching even when every URL returns HTTP 200.
- Server publishing must run `tools/optimize_forecast_images.sh` before `tools/build_forecast_catalog.py`. The optimizer preserves the source image mtime so derivative creation does not falsify product publication time.
- The root raw PNG `Precip_hourly_WRF_AllRain_T01_T48_InitUTC_2026-07-06_18_00.png` is 7000x7000 and 5.8 MB, and is intentionally ignored by Git. Use the optimized WebP in `data/current/maps/` for the site.
- The root user-provided `logo_lacs.png` is ignored by Git after copying it into `assets/brand/logo-lacs-source.png`, so repository assets stay under `assets/brand/`.
- AI-generated logo text is risky, so the website header lockup uses the AI-generated icon only; Chinese and English text are rendered from exact typed strings to avoid text hallucination.
- The active header no longer uses the lockup PNG for text. Keep LACS Chinese and English names as HTML text in `index.html`, `ningxia/index.html`, and `shangrao/index.html`.
- GitHub Pages does not provide reliable directory listing for discovering new image folders. Server-side publishing must update `data/current/forecast-runs.json` whenever it adds a new `wrf_montage_YYYYMMDD_HH` or `worknx_summary_YYYYMMDD_HH` directory.
- `tools/build_forecast_catalog.py` intentionally uses product file mtimes for `published_at`, not wall-clock time, so repeated server runs do not create false Git changes when images are unchanged.
- For the WORK_nx/Ningxia forecast, "time" means the image file generation/modification time (`mtime`). Do not substitute the WRF `Times` variable or directory name when deciding the publication time.
- Keep product ownership separate: root `/` and `/ningxia/` are WORK_nx/NX Ningxia products, `/airpots/` is the airport sample service, and `/shangrao/` is Shangrao products. Do not merge these service catalogs.
- Shangrao products must be regional `wrf_montage_*` outputs generated from WORK wrfout through `batch_ncks.sh`, NCL, and montage. Do not publish ready-made `Precip_hourly_Fog_TargetT07_T48_ActualT07_T48_*.png` nationwide products to `/shangrao/`.
- The password gate is client-side because the site is on GitHub Pages. It hides the UI and persists access through localStorage, but anyone inspecting static assets can bypass it. Use a real backend, Cloudflare Access, Netlify/Vercel auth, or another edge/access-control layer if real access control becomes necessary.
- In-app browser verification was attempted but no in-app browser backend was available (`agent.browsers.list()` returned `[]`). Verification was completed via local HTTP checks and image inspection instead.
- Do not use a publishing step such as `rm -rf data/current`. Multiple selectable initial times depend on retaining the timestamped run directories under `data/current/maps/`; use a separate bounded retention policy after successful publication.
- The page can only expose runs present in `data/current/forecast-runs.json`. A source-server directory is not visible to GitHub Pages until its image directory and regenerated catalog are both committed and deployed.
- The image viewer's DOM, event logic, responsive CSS, and local HTTP assets were verified, but a real browser screenshot/touch gesture pass was unavailable in this session because the in-app browser backend list was empty.
- Use atomic publish directories so failed data updates do not break the live site.
- HTTPS via Certbot usually requires the HTTP site to be reachable on port 80, unless using DNS validation.

## Next Recommended Actions

1. Add `www` separately as a CNAME to `keruicode.github.io`. In Aliyun quick-add this can be done by choosing `将网站域名解析到另外的目标域名`, selecting only `www.iaplacs.xyz`, and entering `keruicode.github.io`.
2. Confirm GitHub Pages HTTPS remains enabled for `iaplacs.xyz` after DNS/certificate provisioning.
3. Monitor the `login02` publishing helpers after the next forecast cycles: confirm OSS uploads/skips, the generated catalog still contains only five runs per family, and the post-publish retention pass reports no stale forecast prefixes.
4. Add real airport service products to replace the current samples under `/airpots/`.
5. Later, extend `tools/build_forecast_catalog.py` with additional product scanners when the server starts publishing more product families beyond WRF rainfall montage and WORK_nx summary.
6. Keep GitHub Pages for the app/catalog and OSS for forecast images; move to an additional CDN only if traffic or latency later requires it.
7. Perform one real iPhone/Android check after the `20260710-08` deploy: switch every Ningxia and Shangrao run, switch all four Shangrao frames, then test pinch zoom, drag, reset, and close; repeat at desktop width with wheel zoom.
8. When the local GitHub route is responsive, fast-forward this clean clone after future server commits; do not overwrite concurrent forecast data commits.
