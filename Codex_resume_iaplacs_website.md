# Codex Resume: iaplacs.xyz Website Planning

Last updated: 2026-07-10 01:44 CST

## Resume Commands

```bash
codex resume 019f472c-9bd3-7222-9160-5fa0162a1249
```

```bash
code resume 019f472c-9bd3-7222-9160-5fa0162a1249
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
- `/Users/xiaoxiaotu/_01_IAP/Website/tools/build_forecast_catalog.py`
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

Official references checked during planning:

- Alibaba Cloud DNS add-record documentation.
- Alibaba Cloud ICP filing service page.
- National public security internet filing portal.
- Certbot Nginx instructions.
- GitHub Pages quickstart and publishing-source docs.

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
- The root raw PNG `Precip_hourly_WRF_AllRain_T01_T48_InitUTC_2026-07-06_18_00.png` is 7000x7000 and 5.8 MB, and is intentionally ignored by Git. Use the optimized WebP in `data/current/maps/` for the site.
- The root user-provided `logo_lacs.png` is ignored by Git after copying it into `assets/brand/logo-lacs-source.png`, so repository assets stay under `assets/brand/`.
- AI-generated logo text is risky, so the website header lockup uses the AI-generated icon only; Chinese and English text are rendered from exact typed strings to avoid text hallucination.
- The active header no longer uses the lockup PNG for text. Keep LACS Chinese and English names as HTML text in `index.html` and `shangrao/index.html`.
- GitHub Pages does not provide reliable directory listing for discovering new image folders. Server-side publishing must update `data/current/forecast-runs.json` whenever it adds a new `wrf_montage_YYYYMMDD_HH` or `worknx_summary_YYYYMMDD_HH` directory.
- `tools/build_forecast_catalog.py` intentionally uses product file mtimes for `published_at`, not wall-clock time, so repeated server runs do not create false Git changes when images are unchanged.
- For the WORK_nx comprehensive forecast, "time" means the image file generation/modification time (`mtime`). Do not substitute the WRF `Times` variable or directory name when deciding the publication time.
- In-app browser verification was attempted but no in-app browser backend was available (`agent.browsers.list()` returned `[]`). Verification was completed via local HTTP checks and image inspection instead.
- Use atomic publish directories so failed data updates do not break the live site.
- HTTPS via Certbot usually requires the HTTP site to be reachable on port 80, unless using DNS validation.

## Next Recommended Actions

1. Add `www` separately as a CNAME to `keruicode.github.io`. In Aliyun quick-add this can be done by choosing `将网站域名解析到另外的目标域名`, selecting only `www.iaplacs.xyz`, and entering `keruicode.github.io`.
2. Confirm GitHub Pages HTTPS remains enabled for `iaplacs.xyz` after DNS/certificate provisioning.
3. Update the server-side publishing helpers on `login02` so every WRF montage or WORK_nx summary publish runs `python3 tools/build_forecast_catalog.py` before `git add`, then stages `data/current/forecast-runs.json` together with the image directory.
4. Later, extend `tools/build_forecast_catalog.py` with additional product scanners when the server starts publishing more product families beyond WRF rainfall montage and WORK_nx summary.
5. If image volume grows, keep GitHub Pages for the app and move large map assets to object storage/CDN.
