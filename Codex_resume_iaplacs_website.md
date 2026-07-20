# Codex Resume: iaplacs.xyz Website Planning

Last updated: 2026-07-20 20:14 CST

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

Current fullscreen-viewer repair:

```bash
codex resume 019f5ef8-ca95-7bd0-b4dd-0945145df7f0
```

```bash
code resume 019f5ef8-ca95-7bd0-b4dd-0945145df7f0
```

Current Ningxia boundary-overlay follow-up:

```bash
codex resume 019f5ef8-ca95-7bd0-b4dd-0945145df7f0
```

```bash
code resume 019f5ef8-ca95-7bd0-b4dd-0945145df7f0
```

Current homepage service-button and county-SHP follow-up:

```bash
codex resume 019f472c-9bd3-7222-9160-5fa0162a1249
```

```bash
code resume 019f472c-9bd3-7222-9160-5fa0162a1249
```

## Thread

- Thread ID: `019f472c-9bd3-7222-9160-5fa0162a1249`
- Session log: `/Users/xiaoxiaotu/.codex/sessions/2026/07/09/rollout-2026-07-09T21-58-53-019f472c-9bd3-7222-9160-5fa0162a1249.jsonl`
- Latest diagnostic follow-up thread ID: `019f54bd-2333-7323-a89d-92bf699aec95`
- Latest diagnostic session log: `/Users/xiaoxiaotu/.codex/sessions/2026/07/12/rollout-2026-07-12T13-11-49-019f54bd-2333-7323-a89d-92bf699aec95.jsonl`
- Current Ningxia boundary-overlay follow-up thread ID: `019f5ef8-ca95-7bd0-b4dd-0945145df7f0`
- Current Ningxia boundary-overlay session log: `/Users/xiaoxiaotu/.codex/sessions/2026/07/14/rollout-2026-07-14T12-53-10-019f5ef8-ca95-7bd0-b4dd-0945145df7f0.jsonl`
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

## Latest Work Session: 2026-07-20 Yunnan Airport Precipitation

- User request: add a Yunnan precipitation product to the airport service page, using the same WORK_nx T13-T48 36-hour 6x6 layout as Ningxia/Shangrao, show only the Yunnan regional view, mark 德宏芒市国际机场、西双版纳嘎洒国际机场、普洱澜沧景迈机场 with mini airplane markers, and show the three airport point precipitation amounts separately on the webpage.
- Implemented code commit `ba732a9 Add Yunnan airport precipitation product`:
  - Added `tools/rain_worknx_yunnan_airport_hour_bjt.ncl` for Yunnan T13-T48 hourly precipitation panels with airplane markers.
  - Added `tools/render_worknx_yunnan_airports_overview.sh` to render 36 panels, caption them, montage them into one 6x6 overview, and write `manifest_fragment.json`.
  - Added `tools/extract_yunnan_airport_precip.py` to calculate three airport T13-T48 point precipitation totals from `RAINNC + RAINC`.
  - Added `tools/publish_worknx_yunnan_airports_to_github.sh` to publish the airport Yunnan image set to OSS and commit only JSON catalog changes.
  - Updated `tools/build_forecast_catalog.py` to read `airport_yunnan_YYYYMMDD_HH/` directories and expose the product on `airport`/`main`.
  - Updated `tools/optimize_forecast_images.sh`, README, `docs/deployment.md`, and `docs/repository-structure.md`.
- Implemented safety commit `8a5b442 Preserve forecast services when rebuilding catalog`: `build_forecast_catalog.py` now merges current catalog runs with recent Git catalog versions so missing local image caches do not drop other services when rebuilding.
- Implemented point-coverage commit `4e6e80b Mark uncovered Yunnan airport points`: airport point extraction now marks stations whose nearest WRF grid point is too far away as `outside_domain`; the page metric shows `无网格覆盖`.
- Server publication:
  - Runtime directory: `login02:/data1/elpt_2022_00083/kerui/Website/`.
  - Source WORK_nx run: `/data1/elpt_2022_00083/zhoubj/WORK_nx/2026072000/gfs/wrf/`.
  - Rendered output directory: `/data1/elpt_2022_00083/kerui/Website/worknx_yunnan_airports_overview/20260720_00/`.
  - Published image prefix: `data/current/maps/airport_yunnan_20260720_00/`.
  - Server data commits during this work: `e5c4e0b Update Yunnan airport forecast 20260720_00`, `8c4ec0b Update WORK_nx summary 20260720_00`, `084bcba Update Yunnan airport forecast 20260720_00`.
  - Final repair commit: `a477346 Restore retained runs after latest publishes`.
- Final online catalog state verified from `https://iaplacs.xyz/data/current/forecast-runs.json?v=a477346-2`:
  - `airport`: 1 run, latest `airport_yunnan_20260720_00`.
  - `ningxia`: 5 runs, latest `20260720_00`.
  - `shangrao`: 5 runs, latest `20260720_02`.
  - Airport metrics: 德宏芒市 36h `0.1 mm`; 西双版纳嘎洒 36h `无网格覆盖`; 普洱澜沧景迈 36h `无网格覆盖`.
- OSS verification:
  - Main WebP URL returned `HTTP 200`, `Content-Type: image/webp`, `Content-Length: 1776716`.
  - Preview WebP URL returned `HTTP 200`, `Content-Type: image/webp`, `Content-Length: 380800`.
  - The local visual preview `.tmp/yunnan_airport_preview.webp` was inspected; it shows a 6x6 Yunnan-region precipitation montage with airport markers.
- Important pitfall: the current WORK_nx d01 grid does not cover 西双版纳嘎洒 and 普洱澜沧景迈 at their actual coordinates. The extraction script therefore marks those two airports as `无网格覆盖` instead of publishing misleading `0.0 mm` values. A different domain/source file is needed if true point precipitation for the two southern airports is required.
- Server script compatibility patched directly in `/data1/elpt_2022_00083/kerui/Website/`:
  - `publish_worknx_summary_to_github.sh` and `publish_wrf_montage_to_github.sh` no longer `git add` generated map directories.
  - `prune_iaplacs_oss.sh` now recognizes `airport_yunnan_*` prefixes.
- Final local state after this work: branch `main` equals `origin/main` at `a477346`; `git status --short --branch --untracked-files=no` reports clean.

Verification commands/results from this session:

```bash
python3 -m py_compile tools/build_forecast_catalog.py tools/extract_yunnan_airport_precip.py
bash -n tools/render_worknx_yunnan_airports_overview.sh tools/publish_worknx_yunnan_airports_to_github.sh tools/optimize_forecast_images.sh
git diff --check -- ...
```

Result: all passed.

```bash
tools/build_forecast_catalog.py
```

Final local rebuild result before publishing final catalog: `wrote data/current/forecast-runs.json with 1 airport run(s), 5 ningxia run(s), 5 shangrao run(s)`.

```bash
ssh 10.64.201.2 'cd /data1/elpt_2022_00083/kerui/Website && ./publish_worknx_yunnan_airports_to_github.sh --latest'
```

Result: rendered and uploaded `airport_yunnan_20260720_00`; final successful run pushed `084bcba`, then local repair pushed `a477346`.

```bash
curl --noproxy iaplacs.xyz -fsS 'https://iaplacs.xyz/data/current/forecast-runs.json?v=a477346-2'
```

Result: online JSON returned `airport=1`, `ningxia=5`, `shangrao=5` with the airport point metrics listed above.

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
- `/Users/xiaoxiaotu/_01_IAP/Website/tools/extract_yunnan_airport_precip.py`
- `/Users/xiaoxiaotu/_01_IAP/Website/tools/render_worknx_yunnan_airports_overview.sh`
- `/Users/xiaoxiaotu/_01_IAP/Website/tools/publish_worknx_yunnan_airports_to_github.sh`
- `/Users/xiaoxiaotu/_01_IAP/Website/tools/rain_worknx_yunnan_airport_hour_bjt.ncl`
- `/Users/xiaoxiaotu/_01_IAP/Website/tools/render_worknx_ningxia_overview.sh`
- `/Users/xiaoxiaotu/_01_IAP/Website/tools/publish_worknx_ningxia_to_github.sh`
- `/Users/xiaoxiaotu/_01_IAP/Website/tools/rain_worknx_ningxia_hour_bjt.ncl`
- `/Users/xiaoxiaotu/_01_IAP/Website/tools/rain_wrf_shangrao_hour_bjt.ncl`
- `/Users/xiaoxiaotu/_01_IAP/Website/tools/SHP/ningxia_city_county.*`
- `/Users/xiaoxiaotu/_01_IAP/Website/tools/SHP/shangrao_city_county.*`
- `/Users/xiaoxiaotu/_01_IAP/Website/docs/repository-structure.md`
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
- IAP `login02` was reachable at `10.64.201.2`; `~/bin/ossutil`, `~/.iaplacs-oss.env`, `~/bin/prune_iaplacs_oss.sh`, and `~/iaplacs-site` exist. `ossutil help set-acl` confirmed `ossutil set-acl oss://bucket/object public-read` is supported. Direct `ossutil set-acl` / `ossutil cp` attempts from `login02` hung and were interrupted. The active publisher uploads OSS objects from `server02` through `GITHUB_HOST`, so targeted repair was completed there instead.
- Likely publishing root cause: both publisher scripts use `ossutil cp ... -u --acl public-read`. If an old object already exists, `-u` skips upload and may not repair ACL. Early objects uploaded before public ACL setup can remain private while the catalog still references them.
- Remote publisher hardening was applied to:
  - `/data1/elpt_2022_00083/kerui/Website/publish_worknx_summary_to_github.sh`
  - `/data1/elpt_2022_00083/kerui/Website/publish_wrf_montage_to_github.sh`
- Both scripts now call `verify_public_object` after each `ossutil cp ... -u --acl public-read`. The check uses public `curl --range 0-0`; if the URL is unreadable, the script force-reuploads the same image with `--acl public-read`, cache metadata, and content type, then checks again. This prevents old private OSS objects from staying private when `-u` skips an upload.
- Remote script verification passed on `login02`: both patched scripts passed `bash -n`, and `grep` confirmed `verify_public_object` plus the ACL/readability repair path in both files.
- Targeted OSS repair was completed on `server02` for `worknx_summary_20260710_00`: both the WebP and PNG versions of `Precip_hourly_WRF_AllRain_T01_T48_InitUTC_2026-07-10_00_00` were reuploaded with `--acl public-read`.
- Public HEAD checks after the repair returned `HTTP/1.1 200 OK` for both repaired objects. The WebP reported `Content-Type: image/webp`, `Content-Length: 3461871`, and `Last-Modified: Sun, 12 Jul 2026 11:40:43 GMT`; the PNG reported `Content-Type: image/png`, `Content-Length: 5807434`, and `Last-Modified: Sun, 12 Jul 2026 11:40:44 GMT`.
- Live Shangrao catalog showed six runs: `20260712_02`, `20260711_20`, `20260711_14`, `20260711_08`, `20260711_02`, and pinned/relative `20260710_02`.
- Frontend root cause for the sixth Shangrao run: `app.js` pinned `20260710_02` through `SHANGRAO_PINNED_RUN_IDS`, adding it back after slicing to five. Generator root cause: `tools/build_forecast_catalog.py` had the same `SHANGRAO_PINNED_RUN_IDS` logic and forced that run to relative GitHub Pages URLs.
- Local code changes in this follow-up:
  - `app.js`: removed `SHANGRAO_PINNED_RUN_IDS`, removed `createPinnedShangraoRun`, and made `normalizeShangraoRuns()` strictly normalize/slice/sort at `MAX_DISPLAY_RUNS=5`.
  - `tools/build_forecast_catalog.py`: removed Shangrao pinned-run retention and removed `force_relative`; generated Shangrao catalog will now return only latest `MAX_RUNS` runs.
  - `shangrao/index.html`: removed `当前起报`, `发布时间`, `服务说明`, and `服务区域` UI blocks.
  - `index.html`, `ningxia/index.html`, `shangrao/index.html`, and `airpots/index.html`: bumped shared app query string to `app.js?v=20260712-03`.
- Verification passed:
  - `node --check app.js`
  - `PYTHONPYCACHEPREFIX=/private/tmp/iaplacs_pycache_final python3 -m py_compile tools/build_forecast_catalog.py`
  - `rg` found no `SHANGRAO_PINNED_RUN_IDS`, `createPinnedShangraoRun`, `force_relative`, `当前起报`, `发布时间`, `服务说明`, or `服务区域` in `app.js`, `tools/build_forecast_catalog.py`, and `shangrao/index.html`.
  - Python check against live catalog showed `live_catalog_shangrao=6` but `frontend_after_slice=5`, keeping `['20260712_02', '20260711_20', '20260711_14', '20260711_08', '20260711_02']`.
  - Local preview started at `http://127.0.0.1:5181/`; `curl --noproxy 127.0.0.1 -I -s http://127.0.0.1:5181/shangrao/` returned `HTTP/1.0 200 OK`, and `curl --noproxy 127.0.0.1 -I -s 'http://127.0.0.1:5181/app.js?v=20260712-03'` returned `HTTP/1.0 200 OK`. The preview server was stopped during closeout.
- Deployment commit `c179e5a0c3ef23c2cccf5a224545e38fde2cdefe` (`Fix Shangrao run limit and OSS ACL recovery`) was pushed to `origin/main` based on remote commit `a8b89b2`, using a temporary index so local `data/current` changes were not staged. The deploy changed only seven files: `Codex_resume_iaplacs_website.md`, `airpots/index.html`, `app.js`, `index.html`, `ningxia/index.html`, `shangrao/index.html`, and `tools/build_forecast_catalog.py`.
- Post-deploy checks:
  - `git ls-remote origin refs/heads/main` returned `c179e5a0c3ef23c2cccf5a224545e38fde2cdefe`.
  - `git show origin/main:shangrao/index.html` confirmed `app.js?v=20260712-03` and no `当前起报`, `发布时间`, `服务说明`, or `服务区域` matches.
  - GitHub Pages HEAD checks for `https://iaplacs.xyz/shangrao/index.html?v=c179e5a`, `https://iaplacs.xyz/app.js?v=20260712-03-c179e5a`, and `https://iaplacs.xyz/data/current/forecast-runs.json?v=c179e5a` returned `HTTP 200` with `Last-Modified: Sun, 12 Jul 2026 11:46:10 GMT`. Local `curl` in this environment returned empty bodies for those Pages GET requests despite correct HEAD `Content-Length`, so body-level live verification used the Git tree and HEAD metadata rather than local GET parsing.
- Working-tree caution: local `main` is still ahead/behind remote and has many pre-existing data changes/deletions from server-published forecast updates. Do not stage `data/current` blindly from this local checkout.

## Ningxia Product Text Update

- User requested the homepage Ningxia product wording change:
  - `宁夏降水预报图集` -> `降水预报图集`
  - `WORK_nx 生成的宁夏区域降水预报图集，按起报时次自动归档。` -> `WORK_nx 目录下的降水预报图集，按起报时次手动归档。`
- Site-runtime commit `2c2d824 Update Ningxia precipitation product wording` was pushed to `origin/main`, based directly on remote commit `1551071` using a temporary index. Local stale `data/current` changes were not staged.
- Runtime changes:
  - `tools/build_forecast_catalog.py` now emits the new Ningxia product title and description for future catalogs.
  - `app.js` also normalizes Ningxia product title/description on load, so the current live `forecast-runs.json` can still contain old text while the page displays the new wording immediately.
  - All four HTML entry points now reference `app.js?v=20260714-01`.
- Verification passed:
  - `node --check /private/tmp/iaplacs_app_20260714.js`
  - `python3 -m py_compile /private/tmp/iaplacs_build_forecast_catalog_20260714.py`
  - direct text checks found no old Ningxia title/description in the modified runtime files.
  - Node normalization test against live `forecast-runs.json` produced product title `降水预报图集` and description `WORK_nx 目录下的降水预报图集，按起报时次手动归档。`
  - `git ls-remote origin refs/heads/main` returned `2c2d8246637161c30ba459a31975ae6e37a46bf5`.
  - Live `https://iaplacs.xyz/?v=2c2d824b` and `https://iaplacs.xyz/ningxia/?v=2c2d824b` returned `app.js?v=20260714-01` after Pages cache propagation.
  - Live `https://iaplacs.xyz/app.js?v=20260714-01-2c2d824b` contains `NINGXIA_PRODUCT_TITLE = "降水预报图集"` and `NINGXIA_PRODUCT_DESCRIPTION = "WORK_nx 目录下的降水预报图集，按起报时次手动归档。"`

## Image Loading, Viewer Quality, And Repository Structure Docs

- User requested four follow-up fixes:
  - fullscreen zoom quality should match opening the image in a new tab;
  - a new computer should render the latest image quickly, then keep loading the remaining images in the background;
  - root and `/ningxia/` should remove the local placeholder image and return to catalog-driven local/remote behavior;
  - add a download button in the fullscreen viewer and write a Markdown explanation of the repository structure.
- Site-runtime/docs commit `46145d6 Improve forecast image loading and viewer` was pushed to `origin/main`, based on server-published remote commit `8c414f1`, using a temporary index so concurrent `data/current` updates were preserved.
- Runtime changes:
  - `app.js` now sets the active forecast image directly on the `<img>` first, instead of waiting for `fetch -> blob -> objectURL`; this lets the browser render the latest WebP as soon as the URL is known.
  - Background preloading now starts after the active image has loaded, skips competing with the active image first, and still stores retained service images through browser Cache Storage for fast later switching.
  - Cache Storage keys are normalized to absolute URLs so relative fallback images are not pruned incorrectly.
  - The fullscreen viewer now prefers `frame.full_file`, `download_file`, `png_file`, or inferred `.png` when the catalog only has `.webp`; it falls back to WebP if the PNG cannot be fetched.
  - The viewer toolbar now has a left-side `下载原图` button. Download uses the cached/fetched viewer image blob when possible and falls back to opening the source URL.
  - All four HTML entry points now preconnect to the OSS host, use `fetchpriority="high"` on `#forecastImage`, load `styles.css?v=20260714-02` and `app.js?v=20260714-02`, and root `/` plus `/ningxia/` no longer have a hard-coded local placeholder `src`.
  - `tools/build_forecast_catalog.py` now keeps WebP as the normal `file` preview and adds `full_file`/`full_bytes` for the PNG original when a PNG exists.
  - Added `docs/repository-structure.md` explaining GitHub Pages vs OSS vs IAP server responsibilities, data directory ownership, and why `data/current` should not be blindly staged from local `lazygit`.
  - `README.md` links to `docs/repository-structure.md`; `docs/deployment.md` now correctly says `/` and `/ningxia/` are Ningxia WORK_nx routes.
- Verification passed:
  - `node --check app.js`
  - `PYTHONPYCACHEPREFIX=/private/tmp/iaplacs_pycache_20260714 python3 -m py_compile tools/build_forecast_catalog.py`
  - `git diff --check`
  - text check found no `wrf_precip_20260706_1800`, no `20260712-03`, no old Ningxia product title, and no old Ningxia product description in the modified site files.
  - Local HTTP preview at `http://127.0.0.1:5182/` returned `HTTP/1.0 200 OK` for `/`, `app.js?v=20260714-02`, and `styles.css?v=20260714-02`; the preview server was stopped during closeout.
  - Direct generator-function test on local sample directories produced WebP `file` plus PNG `full_file` for both Ningxia and Shangrao frames.
  - Public OSS HEAD checks returned `HTTP/1.1 200 OK` for current Ningxia PNG `worknx_summary_20260713_12/...2026-07-13_12_00.png` and current Shangrao PNG `wrf_montage_20260713_02/...overview_6x6_grid.png`.
  - `git ls-remote origin refs/heads/main` returned `46145d6b6f86fee7e5a3383b7eebc1eefc0a7842`.
  - Live `https://iaplacs.xyz/index.html?v=46145d6c`, `https://iaplacs.xyz/?v=46145d6d`, `https://iaplacs.xyz/ningxia/?v=46145d6d`, and `https://iaplacs.xyz/shangrao/?v=46145d6d` load `20260714-02`, include OSS preconnect and `fetchpriority="high"`, and no longer include the hard-coded local placeholder image.
  - Live `https://iaplacs.xyz/app.js?v=20260714-02-46145d6` contains `highQualityFrameSource`, `scheduleServiceImageWarmup`, `cachedImageObjectUrl`, `full_file`, `pngVariantOfFile`, and the `下载原图` viewer button.
  - Live `https://iaplacs.xyz/styles.css?v=20260714-02-46145d6` contains `.viewer-download-button` styles.
  - Live `https://iaplacs.xyz/docs/repository-structure.md?v=46145d6` returned the new repository structure document.
- Working-tree caution remains: local `main` is still behind/ahead relative to server-published remote history and `data/current` has pre-existing staged/unstaged churn. Do not use `git add .`; compare code files against `origin/main` and stage only intended files.

## Safari Viewer Quality And Fast Preview Backfill

- User reported that fullscreen image quality was fixed in Chrome but still looked wrong in Safari, and that a cold Chrome visit still took roughly 5-6 seconds before the selected run image appeared. The requested behavior is: render the clicked/current run quickly first, then queue other retained service images for background caching.
- Site-runtime commits pushed to `origin/main` during this follow-up:
  - `9abd7f0 Improve forecast image preview loading`
  - `680deb2 Reduce forecast preview image weight`
  - `d4bb429 Fix forced preview upload timestamps`
  - final live data commit after backfill: `c2d66a3 Update WORK_nx summary 20260713_12`
- Frontend changes:
  - `app.js` now uses `preview_file || file` for normal page display, so the first visible image is a small `.preview.webp` when the catalog provides one.
  - The active image is assigned directly to `img.src` first; caching starts after active image load instead of blocking the first render behind `fetch -> blob -> objectURL`.
  - `scheduleServiceImageWarmup()` queues the remaining images for the active service after the selected image has loaded, and avoids competing with the active image first.
  - Cache Storage keys are normalized to persistent absolute URLs, so cached preview/full images can be reused across route visits without object-URL key drift.
  - Fullscreen viewer image source still prefers the PNG original through `full_file`, `download_file`, `png_file`, or inferred `.png`; preview WebP is only for the page thumbnail/main display.
  - Safari quality fix: viewer sizing now uses the image's intrinsic natural dimensions plus transform scale, and CSS no longer constrains `.viewer-image` with `max-width`/`max-height`. This avoids Safari scaling an already downsampled rendered layer.
  - Viewer keeps the left-side `下载原图` button.
- Catalog/generator changes:
  - `tools/build_forecast_catalog.py` now groups `.preview.webp` derivatives with their PNG/WebP originals, emits `preview_file`/`preview_bytes`, and keeps `full_file`/`full_bytes` for high-quality viewer/download paths.
  - WRF/Shangrao overview grouping continues to de-duplicate overview candidates and prefer the 6x6 overview where available.
- Preview optimizer changes:
  - `tools/optimize_forecast_images.sh` now creates `.preview.webp` at max `1100x1100>` and quality `70`, which reduced Ningxia previews to about 450 KB and current Shangrao overviews/details to roughly 288-776 KB.
  - Forced preview regeneration now touches output mtime to the current time when `FORCE=1`; normal non-forced derivative generation still preserves source mtime.
- Server publisher changes were copied to both local source and server runtime:
  - `/Volumes/storage/江西VPN-每日预报/remote/publish_worknx_summary_to_github.sh`
  - `/Volumes/storage/江西VPN-每日预报/remote/publish_wrf_montage_to_github.sh`
  - `login02:/data1/elpt_2022_00083/kerui/Website/publish_worknx_summary_to_github.sh`
  - `login02:/data1/elpt_2022_00083/kerui/Website/publish_wrf_montage_to_github.sh`
  - Both publishers now generate/upload `.preview.webp`, honor `IAPLACS_PREVIEW_FORCE=1`, and use the fixed forced-output mtime so `ossutil cp -u` does not skip regenerated smaller previews.
- Backfill completed:
  - Ningxia retained runs: `20260713_12`, `20260713_06`, `20260713_00`, `20260712_18`, `20260712_12`; each has `1/1` preview.
  - Shangrao retained runs: `20260713_02`, `20260712_20`, `20260712_14`, `20260712_08`, `20260712_02`; each has `4/4` previews.
- Verification passed:
  - `node --check app.js`
  - `PYTHONPYCACHEPREFIX=/private/tmp/iaplacs_pycache_safari_preview python3 -m py_compile tools/build_forecast_catalog.py`
  - `bash -n tools/optimize_forecast_images.sh`
  - `bash -n` for both local `/Volumes/storage/江西VPN-每日预报/remote/*.sh` publisher scripts
  - `bash -n` for both server runtime publisher scripts under `/data1/elpt_2022_00083/kerui/Website`
  - `git diff --check`
  - live catalog `https://iaplacs.xyz/data/current/forecast-runs.json?v=20260714-final` showed Ningxia `5` runs with preview bytes `449694`, `455010`, `451682`, `455002`, `456927`; Shangrao `5` runs with `4/4` previews per run.
  - OSS HEAD for latest Ningxia preview returned `HTTP/1.1 200 OK`, `Content-Type: image/webp`, `Content-Length: 449694`, `Cache-Control: public,max-age=604800`.
  - OSS HEAD for latest Shangrao overview preview returned `HTTP/1.1 200 OK`, `Content-Type: image/webp`, `Content-Length: 652702`, `Cache-Control: public,max-age=604800`.
  - Direct download timing from this local machine for latest Ningxia preview was `preview size=449694 time=2.779575`.
- Browser-tool limitation: the user requested local browser testing through `[@电脑]`, but the Chrome extension control reported `Browser is not available: extension`, and Computer Use startup reported `Sky Computer Use service startup request failed`. Real Safari/Chrome GUI cache-clearing verification could not be completed in this Codex session; validation was done through code checks, live GitHub Pages catalog, and direct OSS object checks instead.
- Working-tree caution remains: site/data runtime was verified through `c2d66a3`; a resume-only follow-up commit `fcae20e` was then pushed to `origin/main`. The local checkout still reports branch ahead/behind and `data/current` churn because forecast data is also published by the server. Continue using temporary-index or targeted staging for code/doc changes, and avoid `git add .`.

## Viewer CORS And Preview Repair

- Follow-up thread: `019f5ef8-ca95-7bd0-b4dd-0945145df7f0`.
- Session log: `/Users/xiaoxiaotu/.codex/sessions/2026/07/14/rollout-2026-07-14T12-53-10-019f5ef8-ca95-7bd0-b4dd-0945145df7f0.jsonl`.
- User reported that clicking a forecast image opened a blank fullscreen viewer despite images being only a few MB on the network.
- Computer Use reproduced the live Ningxia fullscreen viewer opening with its image unavailable. Direct public OSS HEAD requests for the referenced original PNG returned `HTTP 200`, but did not include `Access-Control-Allow-Origin`; the response also forces downloads through `Content-Disposition: attachment`.
- Root cause: the fullscreen viewer selected `full_file` / inferred PNG then requested it through `fetch -> Blob -> objectURL`. This crosses from `iaplacs.xyz` to the OSS host, so the browser blocks the fetch without CORS permission. The original `7000x7000` PNG also expands to about `196 MB` decoded, so its 5-6 MB transfer size is misleading.
- Runtime repair in `app.js`:
  - the fullscreen viewer now directly assigns the currently displayed optimized `preview_file`/WebP source to its `<img>`, which is allowed cross-origin and does not create a Blob;
  - the download link still targets `full_file` / the PNG original without making a CORS-gated fetch;
  - removed the viewer download click handler that attempted another cross-origin Blob fetch before falling back.
- Cache-bust repair: `index.html`, `ningxia/index.html`, `shangrao/index.html`, and `airpots/index.html` now reference `app.js?v=20260714-04`.
- Verification completed before deployment:
  - `node --check app.js`
  - `git diff --check`
  - Computer Use opened the deployed `https://iaplacs.xyz/ningxia/?viewer-fix=20260714-04-211b107` in a new Chrome tab, clicked the forecast image, and visually confirmed the fullscreen viewer rendered the complete Ningxia forecast image. The viewer also retained its `下载原图` link to the PNG original.
- Deployment: isolated runtime commit `5eef25d493dca287859331756861939d3b51ad74` (`Fix fullscreen forecast viewer loading`) was pushed to `origin/main` after `a1226a3`, using a temporary index. It includes only `app.js`, the four HTML entry points, and this resume file; no concurrent `data/current` changes were published.
- Viewer layout and quality follow-up:
  - `app.js` now uses the catalogue's medium `file` WebP (currently 3200px, quality 92) for the interactive viewer, while the page retains `preview_file` (1100px) and the download link retains the PNG original. A `viewer_file` catalogue field is supported for a future dedicated viewer derivative.
  - The viewer now calculates a real fitted CSS width/height before applying pan and zoom. Its baseline is `100%`, so the centered grid layout remains correct across browser viewport heights; zoom stays available up to `600%`.
  - All four entry points now request `app.js?v=20260714-05`.
  - Isolated runtime commit `f3f11c3eb25d21d95ea676d6fd1a9f96c94d3bed` (`Improve forecast viewer fit and clarity`) was pushed to `origin/main` after `fe5d5e6` using a temporary index. It contains only `app.js` and the four HTML cache-bust entry points.
- Verification completed after deployment:
  - `node --check app.js`
  - `git diff --check`
  - Computer Use opened `https://iaplacs.xyz/ningxia/?viewer-layout-verify=20260714-05-f3f11c3`, opened the live Ningxia image, and visually confirmed the complete image was centered in the viewport at `100%`; the zoom control reached `125%` without losing the viewer state. The download link still targets the PNG original.
- Idle image warmup follow-up:
  - Removed the CORS-incompatible cross-origin `fetch`/Blob and Cache Storage prefetch path. After the first forecast image renders, the page schedules a native `Image` warmup queue through `requestIdleCallback` (with a timer fallback).
  - The queue first warms the current frame's medium viewer WebP, then continues through the active service's retained preview and viewer images at one request at a time. Temporary preload image objects are released after loading, allowing the browser HTTP cache to accelerate later clicks without retaining all decoded 3200px bitmaps.
  - Warmup is skipped if the browser reports Save-Data, `slow-2g`, or `2g`.
  - `README.md` and `docs/deployment.md` now document the direct-image/CORS limitation and idle warmup behavior. All entry points request `app.js?v=20260714-06`.
  - Isolated runtime/docs commit `ff8129ea48c93f1e56095a9dc0604ac623b08fcb` (`Warm forecast images during browser idle time`) was pushed to `origin/main` after `f2480f6`.
- Verification completed after deployment:
  - `node --check app.js`
  - `git diff --check`
  - Computer Use opened `https://iaplacs.xyz/shangrao/?idle-preload-verify=20260714-06-ff8129e`, waited for idle warmup, opened the live Shangrao overview in the viewer, and visually confirmed the complete medium-resolution image rendered centered. The viewer's PNG download link remained intact.
- Toolbar download follow-up:
  - Added a second `下载原图` link immediately beside `放大查看` in all four page toolbars. It updates with the selected run/product/frame, points to `full_file` / the PNG original when present, and receives the generated download file name. The existing viewer-top download link remains unchanged.
  - Updated the narrow-screen toolbar so its two text actions remain adjacent and wrap safely with the previous/next icon buttons.
  - All entry points now request `app.js?v=20260714-07`.
  - A concurrent forecast publisher update initially rejected the UI push. The final isolated commit was rebased onto live data commit `eaf56fc` and published as `509c53c7ba2c1179ec935e8f62b2d47b4f0c09ad` (`Add forecast download link to toolbar`), with no data files included.
- Verification completed:
  - `node --check app.js`
  - `git diff --check`
  - Temporary-index diff confirmed only `app.js`, `styles.css`, and the four HTML entry points changed.
  - Computer Use GUI recheck could not start because the Sky native pipe failed; use a normal browser refresh to visually confirm the new toolbar action if needed.
- Current status: production serves the fitted medium-WebP viewer, idle warmup, and two original-download entry points through `app.js?v=20260714-07`. Do not stage concurrent `data/current` changes.

## Ningxia Regional 6x6 Overview Preparation

- User requested that the root `/` (and the matching `/ningxia/` service) stop using the nationwide WORK_nx T01--T48 sheet. The required product is one Ningxia-region overview per initial time, with no Shangrao-style detail-page splitting.
- Confirmed layout: omitting T01--T12 leaves T13--T48 inclusive, exactly 36 hourly panels, so the requested overview is a single 6x6 grid.
- Existing source sheets such as `Precip_hourly_WRF_AllRain_T01_T48_InitUTC_*.png` are nationwide 48-hour products. Replacing them correctly requires rendering from the corresponding `wrfout_d01_*` fields on `login02`; CSS or catalog-only cropping would be inaccurate.
- Commit `781d0a445f9faae102863016471a06956a6e01f9` (`Prepare Ningxia regional precipitation overview`) was pushed to `origin/main`. It contains only:
  - `tools/rain_worknx_ningxia_hour_bjt.ncl`: computes hourly precipitation from WORK_nx WRF output, crops to the Ningxia domain (104.0--107.8E, 35.0--39.7N), and writes T13--T48 panels.
  - `tools/render_worknx_ningxia_overview.sh`: locates stable WORK_nx source/run files, invokes the NCL renderer, validates 36 panels, and assembles one `*_Ningxia_T13_T48_*_combined_overview_6x6_grid.png` image. It accepts `--latest` or `--recent COUNT`; default is one run.
  - `tools/build_forecast_catalog.py`: when a `worknx_summary_<run>` directory contains the new Ningxia overview, it selects that overview rather than the legacy nationwide raw sheet and labels the lead time `T13-T48`.
  - `docs/deployment.md`: documents running `tools/render_worknx_ningxia_overview.sh --recent 5` before the normal publisher/catalog rebuild.
- Local verification passed: `bash -n tools/render_worknx_ningxia_overview.sh`, `python3 -m py_compile tools/build_forecast_catalog.py`, `git diff --check`, and a fixture-based catalog test selecting the `T13-T48` regional overview in preference to the legacy sheet. Local NCL is unavailable, so WRF rendering was not simulated locally.
- Blocking condition at closeout: `ssh -tt -o BatchMode=yes -o ConnectTimeout=8 10.64.201.2 ...` timed out on port 22 repeatedly. Therefore the actual remote WRF fields could not be inspected, no Ningxia shapefile path could be confirmed, no PNGs were generated, and the latest five run directories were not replaced. The production site still displays the existing nationwide images until this remote operation is performed.
- Once `login02` connectivity is restored:
  1. Inspect the actual `wrfout_d01_*` and Ningxia boundary shapefile, set `NINGXIA_SHP_FILE` if present, and copy the NCL/renderer to `/data1/elpt_2022_00083/kerui/Website`.
  2. Run `tools/render_worknx_ningxia_overview.sh --recent 5` against `/data1/elpt_2022_00083/zhoubj/WORK_nx`.
  3. Extend the active WORK_nx publisher/cron to publish each generated regional overview (PNG, normal WebP, preview WebP) into its matching `worknx_summary_<UTC-run>` directory, then rebuild the catalog and publish OSS/GitHub Pages.
  4. Verify the five retained Ningxia runs each expose exactly one `T13-T48` 6x6 regional frame and that the public PNG/WebP/preview URLs return HTTP 200.

## Ningxia Regional 6x6 Execution

- `login02` SSH was restored on 2026-07-15. All five retained WORK_nx runs had an adjacent `wrfout_d01_*`; NCL and ImageMagick `montage` are installed on the server.
- The renderer was corrected after live execution: it explicitly defines the hourly precipitation missing value and treats an unset `NINGXIA_SHP_FILE` as an empty string. It labels every panel `Ningxia region` and renders the 104.0--107.8E, 35.0--39.7N regional domain. No Ningxia province-boundary shapefile was found under the available IAP paths, so the operational product currently uses this crop, national outline settings, and geographic ticks.
- A live render of `20260714_18` produced all 36 T13--T48 panels and a valid `6168x6168` PNG overview. The generated regional overview is about 0.64--0.67 MB PNG before WebP derivatives.
- Deployed runtime scripts on `login02:/data1/elpt_2022_00083/kerui/Website`:
  - `rain_worknx_ningxia_hour_bjt.ncl`
  - `render_worknx_ningxia_overview.sh`
  - `publish_worknx_ningxia_to_github.sh`
  - patched `publish_worknx_summary_to_github.sh`, which now accepts `SOURCE_IMAGE_GLOB` for regional inputs.
- The maintained source script was also updated at `/Volumes/storage/江西VPN-每日预报/remote/publish_worknx_summary_to_github.sh`; the new wrapper is `/Volumes/storage/江西VPN-每日预报/remote/publish_worknx_ningxia_to_github.sh`.
- The hourly cron was changed from `publish_worknx_summary_to_github.sh` to `publish_worknx_ningxia_to_github.sh`; the prior crontab is backed up on `login02` at `/tmp/iaplacs-crontab-before-ningxia-region-20260715`.
- Isolated site code/docs commit `1ad7cf36a61a03c7abc06a45ccf941da51fcebd0` (`Publish Ningxia regional 6x6 overviews`) was pushed. It includes the corrected NCL renderer, `tools/publish_worknx_ningxia_to_github.sh`, and updated deployment instructions.
- Backfill completed for all five retained Ningxia runs: `20260714_18`, `20260714_12`, `20260714_06`, `20260714_00`, and `20260713_18`. Server-published data commits were `14a6517`, `8e5c6a5`, `eb4103b`, `a4b8ff0`, and `bc2c73d`.
- Final verification:
  - `forecast-runs.json` reports exactly five Ningxia runs; each has exactly one frame, whose `lead_label` is `T13-T48` and whose files are `Precip_hourly_WRF_Ningxia_T13_T48_*_combined_overview_6x6_grid`.
  - All 15 public OSS assets (five preview WebPs, five 3200px WebPs, and five original PNGs) returned `HTTP 200` with the expected image content type.
  - `https://iaplacs.xyz/data/current/forecast-runs.json?ningxia-region=bc2c73d` returned `HTTP/2 200`, `Content-Type: application/json`, and the current data commit timestamp.

## Ningxia Provincial Boundary Overlay

- The Shangrao plotting source `/Volumes/storage/江西VPN-每日预报/local/SHP/省界_region.{dbf,prj,sbn,sbx,shp,shx}` is a nationwide provincial-boundary dataset (WGS84), not a Jiangxi-only layer. All six sidecar files were copied to `login02:/data1/elpt_2022_00083/kerui/Website/SHP/`.
- `tools/render_worknx_ningxia_overview.sh` now defaults `NINGXIA_SHP_FILE` to `$SCRIPT_DIR/SHP/省界_region.shp`; the NCL renderer overlays its province boundaries on each Ningxia panel. A live `6168x6168` 6x6 render was visually checked after the overlay.
- The active Ningxia wrapper now forces rebuild of normal and preview WebPs, and forces the active-run OSS upload. The maintained and runtime publishers were patched so the force flag also reaches server02 and only reuploads the current run rather than every retained map.
- The cron remains at minute 55 and invokes `publish_worknx_ningxia_to_github.sh`.
- Public PNG SHA-256 values exactly matched the freshly rendered server files for `20260715_00`, `20260714_18`, `20260714_12`, `20260714_06`, and `20260714_00`; their five PNGs plus five normal and five preview WebPs all returned `HTTP 200` on OSS.
- Site code commit `d57042e846fd4fd457b3a800e9edff2b404a3bff` (`Overlay provincial boundaries on Ningxia forecasts`) was pushed to `main`.

## Ningxia Captioned Montage Refresh

- Root cause of the green text: the Ningxia NCL palette has green at color index `1`, which NCL used for default title, coordinate, and colour-bar text. The renderer now explicitly uses black for all map-interface text.
- Removed `tiMainString` completely. The NCL product has no map title and uses `mpOutlineBoundarySets = "NoBoundaries"`; only the copied Shangrao nationwide provincial-boundary SHP supplies the black administrative outlines.
- Before each `6x6` montage, `render_worknx_ningxia_overview.sh` creates a captioned copy of every panel with ImageMagick: a uniform `92px` white top band and a `62px` black bold valid-time label (for example `07-15 20:00-21:00`). This makes labels independent from the rainfall palette and gives all 36 tiles identical dimensions.
- All five retained runs (`20260715_00`, `20260714_18`, `20260714_12`, `20260714_06`, `20260714_00`) were rerendered with the SHP and captioned montage, then force-published as PNG, normal WebP, and preview WebP.
- The final `20260715_00` original PNG is `6168x6720`; its public OSS SHA-256 (`03a3b2f8ef3ff970cf4606f8b81dc4f662cc83ff35f8b2e00597f744edcef523`) exactly matches the server output. All 15 public assets across the five retained runs returned `HTTP 200` with image content types.

## Forecast Asset Cache Invalidation

- The updated Ningxia images were present in the live catalog and OSS, including a newly generated `2937x3200` normal WebP. The apparent stale page was browser caching, not a failed publication: OSS serves these fixed object URLs with `Cache-Control: public,max-age=604800` (seven days).
- `app.js` had a versioned asset URL helper, but it only used `frame.version` or `run.published_at`. The renderer deliberately preserves the source mtime, so rerendering an existing run retains `published_at` and leaves the browser cache key unchanged.
- `frameAssetSource()` now adds all available main, preview, and full asset sizes to the version token. Any regenerated derivative therefore receives a distinct query URL even when its forecast publication timestamp is intentionally unchanged. The four HTML entry points now load `app.js?v=20260715-09` to force rollout of this client fix.
- Commit `da7b9f5bed1d09cf60a08fa04feeeb4422cf7c47` was pushed and GitHub Pages was verified live: the plain homepage references `app.js?v=20260715-09`, the deployed script contains `assetSizes`, and the resulting versioned Ningxia WebP URL returns `HTTP 200`.

## Ningxia Caption Size and OSS Revalidation

- The Ningxia caption montage now uses a `70px` bold black valid-time label in a `78px` white top band (previously `62px` in `92px`). The label is closer to the map frame while all tiles retain identical dimensions.
- All five retained Ningxia runs were rerendered and republished with the larger caption, black labels, and provincial boundary SHP. The current public normal WebP was visually checked at `2974x3200`.
- The operational publisher was found to set `Cache-Control: public,max-age=604800` on every OSS image, which can mask a replaced object for seven days even when the website catalog changes. Both the `login02` runtime publisher and the maintained `/Volumes/storage/江西VPN-每日预报/remote/publish_worknx_summary_to_github.sh` now set `Cache-Control: no-cache` instead.
- Existing PNG, normal WebP, and preview WebP objects for all five retained runs were force-uploaded with the new metadata. Public verification for the current normal WebP returned `HTTP 200`, a new ETag, and `Cache-Control: no-cache`; all 15 image URLs returned `HTTP 200`.

## Ningxia Shangrao Palette Alignment

- The Ningxia precipitation palette was replaced with the exact Shangrao thresholds: `0`, `1.5`, `7`, `15`, `40`, and `50 mm`. It now uses Shangrao's white, light-green, green, light-blue, deep-blue, magenta, and brown-red sequence.
- This corrects the previous Ningxia palette, whose different levels and fill-index sequence could make the top category appear green. The maximum class now renders brown-red and the colour-bar labels match Shangrao exactly.
- All five retained Ningxia runs were rerendered and force-published as PNG, normal WebP, and preview WebP. A public `20260715_00` WebP was visually checked: it has the brown-red top colour, `0/1.5/7/15/40/50` labels, black enlarged dates, and the provincial boundary overlay. It returned `HTTP 200` with `Cache-Control: no-cache`.

## Ningxia Scheduled Publishing Recovery

- Follow-up thread: `019f5ef8-ca95-7bd0-b4dd-0945145df7f0`.
- Session log: `/Users/xiaoxiaotu/.codex/sessions/2026/07/14/rollout-2026-07-14T12-53-10-019f5ef8-ca95-7bd0-b4dd-0945145df7f0.jsonl`.
- On 2026-07-16, WORK_nx already contained stable source sheets and adjacent `wrfout_d01_*` fields for `20260715_06` and `20260715_12`, but the public Ningxia catalogue remained at `20260715_00`.
- Root cause: the minute-55 cron job starts with a minimal `PATH` and no `NCARG_ROOT`; the renderer used `command -v ncl`, so the job stopped with `ERROR: ncl is required` before drawing or uploading.
- `tools/render_worknx_ningxia_overview.sh` now defaults to the installed server paths `NCL_BIN=/public/software/apps/ncl_ncarg/ncl630/bin/ncl` and `NCL_ROOT=/public/software/apps/ncl_ncarg/ncl630`, verifies both, exports `NCARG_ROOT`, and invokes the absolute NCL binary. Overrides remain available through the two environment variables.
- The repaired renderer was deployed to `login02:/data1/elpt_2022_00083/kerui/Website/` and passed a real cron-like test using `env -i HOME="$HOME" PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin ./render_worknx_ningxia_overview.sh --recent 1`; it rendered the regional `20260715_12` T13--T48 6x6 overview successfully.
- The normal publisher then processed `20260715_06` and `20260715_12`. Remote `origin/main` contains the updated catalogue with Ningxia `latest_run: 20260715_12`; the latest public catalogue check also reports `20260715_12`.
- Public OSS verification for the new normal WebP returned `HTTP 200`, `Content-Type: image/webp`, `Content-Length: 1633021`, and `Cache-Control: no-cache`. The image is therefore uploaded and publicly readable; the home page now has a catalogue entry for it.

## Homepage Buttons And County SHP Overlays

- Follow-up thread: `019f472c-9bd3-7222-9160-5fa0162a1249`.
- Session log: `/Users/xiaoxiaotu/.codex/sessions/2026/07/09/rollout-2026-07-09T21-58-53-019f472c-9bd3-7222-9160-5fa0162a1249.jsonl`.
- Working directory: `/Users/xiaoxiaotu/_01_IAP/Website`.
- User requested homepage buttons for Shangrao service and airport service, and city/county SHP overlays for Ningxia and Shangrao only.
- `index.html` now shows two homepage service-entry buttons in the topbar: `上饶服务` linking to `./shangrao/` and `机场服务` linking to `./airpots/`. The homepage stylesheet cache key was bumped to `styles.css?v=20260718-01`.
- `styles.css` now includes responsive `home-service-links` / `home-service-link` styles. On mobile, the buttons wrap as full-width topbar controls.
- Generated two filtered SHP datasets under `tools/SHP/`:
  - `ningxia_city_county.*`: 21 Ningxia city/county features, bbox `[104.2790756225586, 35.23535537719738, 107.65174865722668, 39.38087844848633]`.
  - `shangrao_city_county.*`: 12 Shangrao county/district/city features, bbox `[116.22401717600007, 27.803600632000013, 118.4821187980001, 29.701984072000016]`.
- `tools/render_worknx_ningxia_overview.sh` now passes both `NINGXIA_PROVINCE_SHP_FILE` and `NINGXIA_COUNTY_SHP_FILE` to NCL. The county default is `$SCRIPT_DIR/SHP/ningxia_city_county.shp`; `NINGXIA_SHP_FILE` remains a compatibility alias for the province outline.
- `tools/rain_worknx_ningxia_hour_bjt.ncl` now draws a thin city/county boundary layer first, then a thicker province outline layer.
- Added deployable `tools/rain_wrf_shangrao_hour_bjt.ncl`, based on the Shangrao WRF workflow, with `SHANGRAO_COUNTY_SHP_FILE` defaulting to `./SHP/shangrao_city_county.shp` and `SHANGRAO_PROVINCE_SHP_FILE` defaulting to `./SHP/省界_region.shp`.
- Updated `README.md`, `docs/deployment.md`, and `docs/repository-structure.md` so the server operator copies only the filtered Ningxia and Shangrao SHPs, not nationwide or full-Jiangxi county layers, into the server runtime `SHP/` directory.
- Local preview server was started at `http://127.0.0.1:5182/`. The process is listening on `127.0.0.1:5182`, but this sandbox refused same-host client connections from separate commands with `PermissionError [Errno 1] Operation not permitted`, so preview verification used static HTML checks plus `lsof`.

Verification commands/results:

```bash
bash -n tools/render_worknx_ningxia_overview.sh tools/publish_worknx_ningxia_to_github.sh tools/optimize_forecast_images.sh
```

Result: passed.

```bash
python3 - <<'PY'
from pathlib import Path
import shapefile
expected = {
    'tools/SHP/ningxia_city_county.shp': 21,
    'tools/SHP/shangrao_city_county.shp': 12,
}
for file_name, count in expected.items():
    reader = shapefile.Reader(file_name, encoding='utf-8', encodingErrors='replace')
    actual = len(reader.shapes())
    print(file_name, actual, reader.bbox)
    if actual != count:
        raise SystemExit(f'{file_name}: expected {count}, got {actual}')
PY
```

Result: Ningxia SHP has `21` features; Shangrao SHP has `12` features.

```bash
rg -n "home-service-link|上饶服务|机场服务|20260718-01" index.html styles.css
```

Result: homepage contains the two service buttons and the new stylesheet cache key.

```bash
git diff --check -- index.html styles.css tools/render_worknx_ningxia_overview.sh tools/rain_worknx_ningxia_hour_bjt.ncl README.md docs/deployment.md docs/repository-structure.md
```

Result: passed.

Notes for deployment:

- NCL is not installed in this local environment, so actual map rendering was not executed locally. Run the Ningxia and Shangrao NCL workflows on the IAP server after copying the SHP sidecar files.
- The active Shangrao production workflow currently lives outside this GitHub Pages repo under `/Volumes/storage/江西VPN-每日预报/shared/` and on `login02`; copy or replace its rainfall NCL with `tools/rain_wrf_shangrao_hour_bjt.ncl` before rerendering Shangrao products.
- Existing dirty `data/current` changes were present before this work and were not cleaned or reverted.

## IAP Server County-SHP Deployment And Publication

- User confirmed the IAP server was open and asked that real plotting be adjusted on the IAP server while local and GitHub code remain consistent.
- Connected to `login02` at `10.64.201.2` and used runtime directory `/data1/elpt_2022_00083/kerui/Website`.
- Backed up runtime plotting scripts to `/data1/elpt_2022_00083/kerui/Website/backups/county-shp-20260718_195024/`.
- Copied the filtered SHP sidecars and updated NCL/render scripts into the server runtime:
  - `SHP/ningxia_city_county.*`
  - `SHP/shangrao_city_county.*`
  - `rain_worknx_ningxia_hour_bjt.ncl`
  - `render_worknx_ningxia_overview.sh`
  - `rain_wrf_shangrao_hour_bjt.ncl`
  - runtime `rain_wrf_hour_bjt.ncl` was replaced with the deployable Shangrao county-SHP version.
- Remote checks passed:
  - `bash -n render_worknx_ningxia_overview.sh publish_worknx_ningxia_to_github.sh publish_wrf_montage_to_github.sh submit_wrf_pipeline.sh auto_pipeline_server.sh`
  - `ncl -V` returned `6.3.0` from `/public/software/apps/ncl_ncarg/ncl630/bin/ncl`.
  - Runtime script greps confirmed both Ningxia and Shangrao draw a thin county layer plus thicker province outline.
- Published the latest Ningxia regional run with `./publish_worknx_ningxia_to_github.sh --latest`.
  - Rendered and published `20260718_00`.
  - Public OSS image verified by the publisher:
    `https://iaplacs-forecast-images-hk.oss-cn-hongkong.aliyuncs.com/iaplacs/data/current/maps/worknx_summary_20260718_00/Precip_hourly_WRF_Ningxia_T13_T48_InitUTC_2026-07-18_00_00_combined_overview_6x6_grid.png`.
  - GitHub data commit: `93fba94 Update WORK_nx summary 20260718_00`.
- Submitted the Shangrao WRF pipeline with `./submit_wrf_pipeline.sh`.
  - Slurm job: `38238417`.
  - Finished successfully at `2026-07-18 20:18:22 CST`.
  - The run also produced a partial `20260718_14` 6x1 output; it was intentionally excluded from publishing because it was not a complete 6x6 overview plus three detail sheets.
- Published the latest five complete Shangrao WRF runs from `wrf_hourly_png` using `PREFIX_FILE=/tmp/iaplacs_latest5_full_wrf_prefixes.txt ./publish_wrf_montage_to_github.sh --all-current`.
  - Published runs: `20260717_08`, `20260717_14`, `20260717_20`, `20260718_02`, and `20260718_08`.
  - GitHub data commits: `aea89ef`, `3d5c25b`, `8241889`, `6c1346f`, and `b678e14`.
  - OSS retention kept exactly five `worknx_summary_*` and five `wrf_montage_*` families; no retained objects were deleted.
- Live catalog verification at `https://iaplacs.xyz/data/current/forecast-runs.json`:
  - `published_at`: `2026-07-18T20:18:20+08:00`
  - `ningxia.latest_run`: `20260718_00`
  - Ningxia runs: `20260718_00`, `20260717_18`, `20260717_12`, `20260717_06`, `20260717_00`
  - `shangrao.latest_run`: `20260718_08`
  - Shangrao runs: `20260718_08`, `20260718_02`, `20260717_20`, `20260717_14`, `20260717_08`
  - No partial `20260718_14` run appears in the live Shangrao catalog.
- Public OSS HEAD checks returned `HTTP 200`:
  - Ningxia latest normal WebP: `Content-Type: image/webp`, `Content-Length: 1631387`, `Cache-Control: no-cache`.
  - Shangrao latest overview WebP: `Content-Type: image/webp`, `Content-Length: 3568776`, `Cache-Control: public,max-age=604800`.
- Local/GitHub code sync was completed from a clean temporary worktree at `/private/tmp/iaplacs-code-sync-20260718-2032`.
  - Code/docs/SHP commit: `ebae4f12efcc2276fedbf83df56c1d14ae3d60ab` (`Add county boundary overlays`), pushed to `origin/main`.
  - Commit contents intentionally excluded `data/current`; server-published forecast data commits remain separate.
  - Local file-level verification compared all 37 `origin/main` tracked files outside `data/current/` against the original workspace and found `missing=[]`, `different=[]`.
  - The original local `main` pointer/index was then aligned to `origin/main` with `git reset --mixed origin/main` after creating backup branch `backup-main-before-county-sync-20260718` at the old local HEAD. Working tree files were not overwritten.
  - `git diff --name-only -- . ':!data/current'` and `git diff --cached --name-only -- . ':!data/current'` were both empty after alignment.
  - The original local checkout still contains `data/current` forecast-image churn because the server/GitHub data tree has advanced while the local image tree is incomplete; future code changes should continue to avoid `git add .` unless the data state is intentionally refreshed.
- Live homepage verification after the code push confirmed `https://iaplacs.xyz/` contains `styles.css?v=20260718-01`, `上饶服务`, `机场服务`, `./shangrao/`, and `./airpots/`.

## Service Entry Button Cleanup

- User requested consistent service options across the three service pages, with only two options shown on each page, and asked to remove the text content from the two airport `服务说明` blocks while retaining the `服务说明` label/header.
- Updated service entry buttons:
  - Root Ningxia page `/`: `上饶服务` and `机场服务`.
  - `/ningxia/`: `上饶服务` and `机场服务`.
  - `/shangrao/`: `宁夏服务` and `机场服务`.
  - `/airpots/`: `宁夏服务` and `上饶服务`.
- Bumped all four entry pages to `styles.css?v=20260718-02` so the service-button styling is fetched consistently on non-root pages.
- Airport page cleanup:
  - Removed the dynamic `sourceNote` paragraph from the left `服务说明` block.
  - Removed the `Airport` sublabel and dynamic `productNote` paragraph from the right `服务说明` block.
  - `app.js` already guards missing elements through `setText(element, text)`, so removing the airport IDs is safe.
- Verification:
  - `node --check app.js`: passed.
  - `git diff --check -- index.html ningxia/index.html shangrao/index.html airpots/index.html`: passed.
  - `rg -n "styles.css\\?v=|home-service-link|宁夏服务|上饶服务|机场服务|id=\"sourceNote\"|id=\"productNote\"|服务说明" index.html ningxia/index.html shangrao/index.html airpots/index.html`: confirmed service links and confirmed airport no longer has `sourceNote` / `productNote` IDs.
  - Local file-content check confirmed all four entry pages contain the expected two service links; airport page no longer contains `id="sourceNote"`, `id="productNote"`, `Airport`, `正在读取机场服务清单`, or `正在读取机场产品说明`.
  - Code commit: `3f94290` (`Align service entry links`), pushed to `origin/main`.
  - Online checks with cache-busting URLs confirmed deployed HTML for `/`, `/ningxia/`, `/shangrao/`, and `/airpots/`; `/airpots/?v=3f94290` returned the new service links and did not contain the removed airport service-note IDs/text.

## 2026-07-20 Lightweight Sync Discussion

- The user asked how to keep local and GitHub repositories synchronized without downloading or checking out the large forecast image set on every code change.
- The user chose option 2: move routine forecast images out of the GitHub repository and keep GitHub Pages as the app/catalog host while OSS serves images.
- Current local state before choosing a strategy:
  - `main` is behind `origin/main` by 65 commits because the server has continued publishing forecast-image/data commits.
  - The code paths outside `data/current` are clean.
  - `data/current` contains local generated-data churn from earlier work and should not be blindly committed or restored unless intentionally refreshing forecast data.
  - A binary patch backup of the pre-Yunnan `data/current` diff was saved at `/private/tmp/iaplacs_data_current_pre_yunnan.patch`.
  - A long `git restore --source=origin/main -- data/current` was interrupted; the resulting stale `.git/index.lock` was removed.
- Implemented repository policy changes in `.gitignore`, `README.md`, `docs/repository-structure.md`, and `docs/deployment.md`:
  - generated forecast directories under `data/current/maps/worknx_summary_*`, `data/current/maps/wrf_montage_*`, and future `data/current/maps/airport_yunnan_*` are ignored by Git;
  - server-generated `.png` and `.webp` files directly under `data/current/maps/` are ignored;
  - the server should upload PNG/WebP/preview WebP files to OSS, build `forecast-runs.json` with OSS URLs, and commit only small catalog files;
  - small static sample SVGs under `data/current/maps/` can remain temporarily until the airport service is replaced by real OSS-backed products.
- While trying to align the local worktree, `git reset --mixed origin/main` exited with status `139` and left `.git/index.lock`; the stale lock was removed and the final image-removal commit was built through a temporary index at `/private/tmp/iaplacs_oss_only_index` instead of checking out image files.
- Recommended direction: keep the server as the data publisher and local development as a code/catalog workflow. GitHub should no longer receive routine generated forecast image blobs.

## 2026-07-20 Yunnan Airport Coordinate Correction

- User asked to verify the real coordinates for 西双版纳嘎洒国际机场、普洱澜沧景迈机场、德宏芒市国际机场 from official/authoritative sources because the manually supplied values might be wrong, then mark airport icons on the map.
- Coordinate source review:
  - 西双版纳嘎洒国际机场: 云南机场集团西双版纳机场 official notice for the phase-IV expansion states the airport datum coordinate as `N21°58′25″ E100°45′44″`; implemented as `21.973611, 100.762222`.
  - 德宏芒市国际机场: the official airport page confirms the airport profile but does not publish coordinates. Used aviation ARP data `24.4000, 98.5333`; implemented as `24.400000, 98.533300`.
  - 普洱澜沧景迈机场: 云南机场集团/CAAC pages confirm the airport identity and operation context but do not publish coordinates. Used aviation data `N22°25′4″ E99°47′2″`; implemented as `22.417778, 99.783889`.
- Code commits pushed:
  - `f744bc8 Correct Yunnan airport coordinates`: updated `tools/extract_yunnan_airport_precip.py` and `tools/rain_worknx_yunnan_airport_hour_bjt.ncl`.
  - `e3fd828 Enlarge Yunnan airport map markers`: enlarged the airplane markers and IATA labels `LUM/JHG/JMJ` on the NCL map.
  - `1b32202 Force Yunnan airport WebP refresh`: made the Yunnan airport publisher force-refresh WebP and preview derivatives after rerendering so the static site does not continue serving old WebP images when PNG mtimes are preserved.
  - `33e698f Update Yunnan airport forecast 20260720_00`: final server-generated catalog update after the forced WebP refresh.
- Server actions:
  - Synced updated local scripts to `login02:/data1/elpt_2022_00083/kerui/Website/`.
  - Ran `./publish_worknx_yunnan_airports_to_github.sh --latest` several times while correcting marker visibility and WebP refresh behavior.
  - Final published prefix remains `airport_yunnan_20260720_00`.
- Verification:
  - `python3 -m py_compile tools/extract_yunnan_airport_precip.py tools/build_forecast_catalog.py`: passed.
  - `bash -n tools/render_worknx_yunnan_airports_overview.sh tools/publish_worknx_yunnan_airports_to_github.sh tools/optimize_forecast_images.sh`: passed.
  - `git diff --check -- tools/extract_yunnan_airport_precip.py tools/rain_worknx_yunnan_airport_hour_bjt.ncl tools/publish_worknx_yunnan_airports_to_github.sh`: passed for the relevant patches.
  - OSS latest WebP URL returned `HTTP 200`, `Content-Type: image/webp`, `Content-Length: 1808640`, and new ETag `9667513A1EE918DD26FD0322A5A048B4`.
  - Online catalog `https://iaplacs.xyz/data/current/forecast-runs.json?v=33e698f` returned `airport=1`, `ningxia=5`, `shangrao=5`.
  - Airport metrics remain: 德宏芒市 `0.1 mm`, 西双版纳嘎洒 `无网格覆盖`, 普洱澜沧景迈 `无网格覆盖`.
  - Visual check of `.tmp/yunnan_airport_preview_marker_refresh.webp` and a cropped full-WebP view confirmed the airport markers and labels are present at the corrected positions.
- Current local state after this work: `main` equals `origin/main` at `33e698f`; only `.tmp/` is untracked.

## 2026-07-20 Yunnan Airport Values and Product Retention

- User requested that all three Yunnan airport precipitation values be modified and shown on the webpage, and that the previous wind and temperature product options remain available.
- Code commit `b8dc26d Show Yunnan airport precip values with retained products`:
  - `tools/extract_yunnan_airport_precip.py` now calculates nearest-grid precipitation for airports outside the current WORK_nx d01 coverage instead of returning `None`.
  - Outside-grid airport metrics are labeled as nearest-grid values, e.g. `0.0 mm (近邻网格)`.
  - `tools/build_forecast_catalog.py` keeps the real Yunnan airport precipitation product first, then appends the existing `机场 2 米气温` and `机场 10 米风场` products to the airport service product list.
  - Airport metric labels are now explicit: `德宏芒市机场降水`, `西双版纳嘎洒机场降水`, and `普洱澜沧景迈机场降水`.
- Server publication:
  - Synced `tools/extract_yunnan_airport_precip.py` to `login02:/data1/elpt_2022_00083/kerui/Website/`.
  - Ran `./publish_worknx_yunnan_airports_to_github.sh --latest`.
  - Server data commit: `38d76ac Update Yunnan airport forecast 20260720_00`.
- Verification:
  - `python3 -m py_compile tools/extract_yunnan_airport_precip.py tools/build_forecast_catalog.py`: passed.
  - `git diff --check -- tools/extract_yunnan_airport_precip.py tools/build_forecast_catalog.py`: passed.
  - Server `airport_precip_totals.json` values:
    - 德宏芒市国际机场: `0.1 mm`, status `ok`, nearest grid distance `0.044` degrees.
    - 西双版纳嘎洒国际机场: `0.0 mm`, status `nearest_grid`, nearest grid distance `1.439` degrees.
    - 普洱澜沧景迈机场: `0.0 mm`, status `nearest_grid`, nearest grid distance `0.935` degrees.
  - Public catalog `https://iaplacs.xyz/data/current/forecast-runs.json?v=38d76ac-2` shows airport products `云南机场降水预报图集`, `机场 2 米气温`, and `机场 10 米风场`.
  - Public airport precipitation metrics now show `德宏芒市机场降水 = 0.1 mm`, `西双版纳嘎洒机场降水 = 0.0 mm (近邻网格)`, and `普洱澜沧景迈机场降水 = 0.0 mm (近邻网格)`.
- Current local state after this work: `main` equals `origin/main` at `38d76ac`; only `.tmp/` is untracked.

## 2026-07-20 WORK_yn Source and Airport Display Cleanup

- User requested cleanup for the Yunnan airport product:
  - remove visible `T13-T48`;
  - explain and correct why the product said `WORK_nx` when it should use `WORK_yn`;
  - darken airplane symbols and remove the characters beside them;
  - remove the descriptions under `机场 2 米气温` and `机场 10 米风场`.
- Explanation and code change:
  - The first implementation reused the Ningxia `WORK_nx` pipeline because `WORK_nx` had a ready-made `Precip_hourly_WRF_AllRain_T01_T48...png` discovery file, while `WORK_yn` only has large `wrfout_d01_*` outputs.
  - This was corrected in commit `f5b4a1f Use WORK_yn for Yunnan airport product`: the Yunnan airport renderer now defaults to `/data1/elpt_2022_00083/zhoubj/WORK_yn`, selects stable complete `wrfout_d01_*` files directly, and skips new/incomplete files via age and size checks.
  - The 2026072006 `WORK_yn` wrfout was only about 3.2 GB and was skipped as incomplete; the publisher correctly selected complete `WORK_yn/2026072000/gfs/wrf`.
- Display changes:
  - Removed the `LUM/JHG/JMJ` text labels from the NCL map and enlarged/darkened the airplane markers.
  - Updated airport catalog note/description from `WORK_nx` to `WORK_yn`.
  - Replaced the airport lead label with `36小时拼图`; follow-up commit `019a83a Hide Yunnan airport lead range label` fixed the remaining catalog generation branch.
  - Cleared the product descriptions for `机场 2 米气温` and `机场 10 米风场`.
- Server publication:
  - Synced the updated renderer, publisher, NCL, and point-extraction scripts to `login02:/data1/elpt_2022_00083/kerui/Website/`.
  - Ran `./publish_worknx_yunnan_airports_to_github.sh --latest` twice: first to switch data source and redraw the map, then to regenerate the catalog after the lead-label fix.
  - Server data commits: `67c95d0 Update Yunnan airport forecast 20260720_00` and final `096f4f6 Update Yunnan airport forecast 20260720_00`.
- Verification:
  - `python3 -m py_compile tools/build_forecast_catalog.py tools/extract_yunnan_airport_precip.py`: passed.
  - `bash -n tools/render_worknx_yunnan_airports_overview.sh tools/publish_worknx_yunnan_airports_to_github.sh`: passed.
  - `git diff --check -- ...`: passed for the touched scripts.
  - Public catalog `https://iaplacs.xyz/data/current/forecast-runs.json?v=096f4f6-2` shows airport note using `WORK_yn`, `lead_label = 36小时拼图`, and no visible `T13-T48` inside the airport service object.
  - Public airport products remain `云南机场降水预报图集`, `机场 2 米气温`, and `机场 10 米风场`; the temperature and wind product descriptions are empty strings.
  - Public airport metrics after switching to `WORK_yn`: 德宏芒市机场降水 `0.0 mm`, 西双版纳嘎洒机场降水 `1.7 mm`, 普洱澜沧景迈机场降水 `0.1 mm`.
  - OSS latest WebP returned `HTTP 200`, `Content-Type: image/webp`, `Content-Length: 1885269`, and ETag `99FCF19E694503B012C1B597B816C754`.
  - Visual inspection of `.tmp/yunnan_airport_preview_no_labels.webp` confirmed the adjacent airport text labels are gone; the airplane markers remain on the map.
- Current local state after this work: `main` equals `origin/main` at `096f4f6`; only `.tmp/` is untracked.

## 2026-07-20 Yunnan Airport Archive and Scheduler Cleanup

- User requested a broader cleanup for the Yunnan airport product:
  - enlarge the 36-panel montage time labels and move them closer to each panel;
  - show each airport's maximum hourly precipitation time and value on the webpage;
  - add Yunnan city/county SHP boundaries;
  - keep generated forecast images out of Mac local Git and GitHub, with historical images archived on the IAP server/OSS instead;
  - add scheduled checks and restart recovery for the IAP server publishing workflow.
- Code/data commits:
  - `d8c9633 Archive Yunnan airport images outside Git`
  - `356c669 Update Yunnan airport forecast 20260720_00`
  - `b65ff6f Enlarge Yunnan airport markers`
  - `c6070a5 Update Yunnan airport forecast 20260720_00`
- Implemented changes:
  - Added `tools/SHP/yunnan_city_county.*`, generated from GADM 4.1 China level-3 boundaries and filtered to Yunnan. Local verification found 125 features and bounds `[97.5341, 21.1394, 106.1942, 29.2511]`.
  - Updated `tools/rain_worknx_yunnan_airport_hour_bjt.ncl` to overlay Yunnan city/county boundaries plus the province outline and to use larger black airplane markers without text labels.
  - Updated `tools/render_worknx_yunnan_airports_overview.sh` so montage labels use larger type and sit closer to the top of each panel.
  - Updated `tools/extract_yunnan_airport_precip.py` to compute total precipitation plus `max_hourly_mm` and the BJT maximum-hour interval for each airport.
  - Updated `tools/build_forecast_catalog.py` so the airport metrics read like `累计 ... mm；最大小时 ... mm MM-DD HH:00-HH:00`.
  - Updated `tools/publish_worknx_yunnan_airports_to_github.sh` so `server02` image folders under `data/current/maps/airport_yunnan_*` are transient and removed after publish; GitHub receives catalog JSON, not generated airport images.
  - Added `tools/publish_workyn_yunnan_airports_if_new.sh` to select the latest stable complete `WORK_yn` wrfout, skip already-published runs using `state/yunnan_airport_last_published.txt`, and support `--force`/`--dry-run`.
  - Updated README and deployment docs to document the WORK_yn source, Yunnan SHP, OSS-backed images, and GitHub catalog-only publishing model.
- Server state:
  - Runtime directory: `login02:/data1/elpt_2022_00083/kerui/Website/`.
  - Current source run: `/data1/elpt_2022_00083/zhoubj/WORK_yn/2026072000/gfs/wrf/`.
  - IAP archive/output directory: `/data1/elpt_2022_00083/kerui/Website/worknx_yunnan_airports_overview/20260720_00/`.
  - Published-run stamp: `/data1/elpt_2022_00083/kerui/Website/state/yunnan_airport_last_published.txt`, value `20260720_00`.
  - Crontab backup before editing: `/data1/elpt_2022_00083/kerui/Website/crontab_archive/crontab-before-yunnan-airport-20260720_193415.txt`.
  - Installed cron entries:
    - `25 * * * * /data1/elpt_2022_00083/kerui/Website/publish_workyn_yunnan_airports_if_new.sh >> /data1/elpt_2022_00083/kerui/Website/logs/yunnan-airport-publish.log 2>&1`
    - `@reboot /bin/sleep 600 && /data1/elpt_2022_00083/kerui/Website/publish_workyn_yunnan_airports_if_new.sh >> /data1/elpt_2022_00083/kerui/Website/logs/yunnan-airport-publish.log 2>&1`
- Final online catalog verification from `https://iaplacs.xyz/data/current/forecast-runs.json?v=c6070a5`:
  - Services retained: `airport=1`, `ningxia=5`, `shangrao=5`.
  - Airport products retained: `云南机场降水预报图集`, `机场 2 米气温`, `机场 10 米风场`.
  - 德宏芒市机场: `累计 0.0 mm；最大小时 0.0 mm 07-20 20:00-21:00`.
  - 西双版纳嘎洒机场: `累计 1.7 mm；最大小时 0.5 mm 07-21 02:00-03:00`.
  - 普洱澜沧景迈机场: `累计 0.1 mm；最大小时 0.0 mm 07-20 21:00-22:00`.
- Verification commands/results:
  - `python3 -m py_compile tools/build_forecast_catalog.py tools/extract_yunnan_airport_precip.py`: passed.
  - `bash -n tools/render_worknx_yunnan_airports_overview.sh tools/publish_worknx_yunnan_airports_to_github.sh tools/publish_workyn_yunnan_airports_if_new.sh`: passed.
  - `git diff --check`: passed.
  - `git ls-files data/current/maps`: only the six static sample SVGs are tracked; no generated forecast PNG/WebP directories are tracked.
  - OSS preview WebP returned `HTTP 200`, `Content-Type: image/webp`, `Content-Length: 534292`.
  - `server02` transient image-cache check `find ~/iaplacs-site/data/current/maps -maxdepth 1 -type d -name "airport_yunnan_*"` returned no directories after publish.
  - Visual inspection of `.tmp/yunnan_airport_preview_c6070a5.webp` confirmed larger time labels, Yunnan city/county boundaries, and no airport text labels.
- Current local state after this work: `main` equals `origin/main` at `c6070a5`; only `.tmp/` is untracked.

## 2026-07-20 City-Level Yunnan and Thicker Shangrao Boundaries

- User requested another rendering adjustment:
  - Yunnan SHP should draw city-level boundaries only, not all counties;
  - Shangrao should still draw only Shangrao city/county boundaries, but with thicker lines;
  - montage time labels should move downward so they sit closer to each panel image.
- Code commit: `d65b957 Use city-level Yunnan boundaries`.
- Server data commits after rerendering:
  - `0afb387 Update Yunnan airport forecast 20260720_00`: Yunnan airport rerender with city-level boundaries and lowered montage labels.
  - `50502db Update WRF montage 20260720_08`: intermediate Shangrao publish that rebuilt montages from old panels after an incorrect source symlink; superseded by the next commit.
  - `9b1355c Update WRF montage 20260720_08`: final Shangrao rerender after NCL successfully regenerated all 36 hourly panels.
- Implemented changes:
  - Generated `tools/SHP/yunnan_city.*` from GADM 4.1 China level-2 boundaries filtered to Yunnan. Verification: 16 city/prefecture features, bounds `[97.5341, 21.1394, 106.1942, 29.2511]`.
  - Removed the tracked `tools/SHP/yunnan_city_county.*` files. Server runtime `SHP/` now has `yunnan_city.*`; `find SHP -name "yunnan_city_county.*"` returned no files.
  - Updated `tools/render_worknx_yunnan_airports_overview.sh` to default to `YUNNAN_CITY_SHP_FILE="$SCRIPT_DIR/SHP/yunnan_city.shp"` and move ImageMagick labels from `-annotate +0+0` to `-annotate +0+24`.
  - Updated `tools/rain_worknx_yunnan_airport_hour_bjt.ncl` to draw the Yunnan city layer at `gsLineThicknessF = 1.8`; the old `YUNNAN_COUNTY_SHP_FILE` env var remains only as a compatibility fallback.
  - Updated `tools/rain_wrf_shangrao_hour_bjt.ncl` to draw Shangrao city/county boundaries at `gsLineThicknessF = 2.8` and set `tiMainOffsetYF = -0.018` so NCL titles sit lower.
  - Synced the same Shangrao script to the actual server runtime entry `rain_wrf_hour_bjt.ncl`, because `run_full_montage_test_once.sh` and the current WRF montage workflow call that filename, not only `rain_wrf_shangrao_hour_bjt.ncl`.
- Rerender/publish details:
  - Yunnan rerender command: `./publish_workyn_yunnan_airports_if_new.sh --force`.
  - Shangrao final rerender used a hard link from `wrfout_d01_20260720_00_rain_vars.nc` into `.tmp/shangrao_rerender_20260720_08/`, then ran `ncl rain_wrf_hour_bjt.ncl`, `bash make_wrf_montages.sh wrf_hourly_png 20260720_08`, and `./publish_wrf_montage_to_github.sh 20260720_08`.
  - The failed symlink path originally pointed one directory too shallow; NCL reported a file-open fatal. The corrected hard link had the same inode as the source file and the final NCL run printed all 36 `drawing:` lines without fatal errors.
- Final online catalog verification from `https://iaplacs.xyz/data/current/forecast-runs.json?v=9b1355c`:
  - Services retained: `airport=1`, `ningxia=5`, `shangrao=5`.
  - Airport metrics retained: 德宏芒市 `累计 0.0 mm；最大小时 0.0 mm 07-20 20:00-21:00`; 西双版纳嘎洒 `累计 1.7 mm；最大小时 0.5 mm 07-21 02:00-03:00`; 普洱澜沧景迈 `累计 0.1 mm；最大小时 0.0 mm 07-20 21:00-22:00`.
  - Latest Shangrao run: `20260720_08`.
- Verification:
  - `bash -n tools/render_worknx_yunnan_airports_overview.sh tools/publish_worknx_yunnan_airports_to_github.sh tools/publish_workyn_yunnan_airports_if_new.sh`: passed.
  - `python3 -m py_compile tools/build_forecast_catalog.py tools/extract_yunnan_airport_precip.py`: passed.
  - `git diff --check`: passed before the code commit.
  - OSS Shangrao preview returned `HTTP 200`, `Content-Type: image/webp`, `Content-Length: 816659`.
  - Visual inspection of `.tmp/yunnan_city_preview_9b1355c.webp` confirmed Yunnan now shows city-level boundaries only and lowered time labels.
  - Visual inspection of `.tmp/shangrao_thick_preview_9b1355c.webp` confirmed Shangrao still shows only Shangrao city/county boundaries and the boundary lines are thicker.
- Current local state after this work before the resume-only commit: `main` equals `origin/main` at `9b1355c`; `.gitignore` has an unstaged user change adding `.tmp`.

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
- Avoid using a normal full `git pull` in a checkout that includes historical forecast image blobs. After the OSS-only cleanup, future pulls should be much lighter because generated forecast map directories are no longer tracked.
- Git LFS is not the preferred fix for this GitHub Pages site because Pages delivery and LFS pointers can be awkward; object storage or sparse/partial Git checkout is cleaner for this forecast-image workload.
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
3. Monitor the next scheduled Ningxia and Shangrao publish cycles after the county-SHP deployment; confirm new products still publish exactly five retained runs per service and that public OSS URLs return `HTTP 200`.
4. Monitor the `login02` publishing helpers after the next forecast cycles: confirm the new OSS readability repair path does not report failures, generated catalogs still contain only five runs per family, and retained OSS image URLs return public `HTTP 200`.
5. Add real airport service products to replace the current samples under `/airpots/`.
6. Monitor the new WORK_yn Yunnan airport cron after the next complete wrfout appears; confirm it publishes once, updates `state/yunnan_airport_last_published.txt`, and leaves no `airport_yunnan_*` image directory in the `server02` GitHub worktree.
7. Later, extend `tools/build_forecast_catalog.py` with additional product scanners when the server starts publishing more product families beyond WRF rainfall montage and WORK_nx summary.
8. Keep GitHub Pages for the app/catalog and OSS for forecast images; move to an additional CDN only if traffic or latency later requires it.
9. Perform one real iPhone/Android check after the `20260710-08` deploy: switch every Ningxia and Shangrao run, switch all four Shangrao frames, then test pinch zoom, drag, reset, and close; repeat at desktop width with wheel zoom.
10. When the local GitHub route is responsive, fast-forward this clean clone after future server commits; do not overwrite concurrent forecast data commits.
