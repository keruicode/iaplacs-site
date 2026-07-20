# iaplacs-site 仓库结构说明

本文说明 `iaplacs.xyz` 当前静态网站仓库的组成、数据流和本地提交原则。

## 一句话结构

网站页面、前端逻辑和预报清单放在 GitHub Pages；预报图从阿里云 OSS 加载；IAP 服务器定时生成图像、上传 OSS、更新 `data/current` 清单并推送到 GitHub。

## 线上访问路径

- `/`：宁夏预报主页，读取 `ningxia` 服务。
- `/ningxia/`：宁夏预报子页面，和主页读取同一套 `WORK_nx` catalog。
- `/shangrao/`：上饶专项服务，读取 WRF 降水拼图 catalog。
- `/airpots/`：机场服务页面，读取云南机场降水产品；没有实况产品时回退样例。

## 主要文件

```text
index.html                 主页，当前是宁夏预报入口
ningxia/index.html          宁夏预报子页面
shangrao/index.html         上饶服务页面
airpots/index.html          机场服务页面
app.js                      页面交互、catalog 读取、图片切换、预加载、放大查看
styles.css                  全站样式
CNAME                       GitHub Pages 自定义域名 iaplacs.xyz
assets/brand/               LACS logo、favicon 等静态品牌资源
data/current/forecast-runs.json  当前服务 catalog，页面主要读取它
data/current/manifest.json       旧版 fallback 清单
data/current/maps/              服务器本地出图/上传缓存，生成预报图不进 Git
tools/build_forecast_catalog.py  从图像目录生成 forecast-runs.json
tools/optimize_forecast_images.sh 图像优化脚本
tools/rain_wrf_shangrao_hour_bjt.ncl 上饶 WRF 出图脚本，可部署到服务器
tools/rain_worknx_yunnan_airport_hour_bjt.ncl 云南机场 WORK_nx 出图脚本
tools/SHP/                    宁夏、上饶服务区市县边界 shp
docs/                       运维、部署和结构说明
Codex_resume_iaplacs_website.md  Codex 断点恢复 handoff
```

## 数据目录约定

当前服务器发布三类目录：

```text
data/current/maps/worknx_summary_YYYYMMDD_HH/
data/current/maps/wrf_montage_YYYYMMDD_HH/
data/current/maps/airport_yunnan_YYYYMMDD_HH/
```

`worknx_summary_*` 对应宁夏预报，显示在 `/` 和 `/ningxia/`。

`wrf_montage_*` 对应上饶服务，显示在 `/shangrao/`。

`airport_yunnan_*` 对应机场服务，显示在 `/airpots/`，内容为云南区域
T13-T48 逐小时降水 6x6 拼图和三个机场点的 36 小时累计降水。

每类产品只保留最近 5 个起报时次。这个规则同时存在于服务器发布脚本、`tools/build_forecast_catalog.py` 和前端 `app.js` 的显示保护里。

## 图片加载方式

正常线上访问时，`forecast-runs.json` 里的图片 URL 指向 OSS：

```text
https://iaplacs-forecast-images-hk.oss-cn-hongkong.aliyuncs.com/iaplacs/...
```

页面主图优先使用小尺寸 `.preview.webp`，保证首次渲染快；没有 preview 时回退普通 WebP。放大查看和下载优先使用同一张图的 PNG 原图；如果 catalog 没有显式 `full_file` 字段，前端会按 `.webp -> .png` 自动推断，失败时回退 WebP。

GitHub 仓库不再跟踪服务器生成的 `data/current/maps/worknx_summary_*`、
`data/current/maps/wrf_montage_*`、`data/current/maps/airport_yunnan_*` 等预报图目录。这些目录只作为服务器本地
出图、优化、上传 OSS 和生成 catalog 的工作缓存。浏览器依赖
`forecast-runs.json` 中的 OSS URL 读图。

## IAP 服务器发布流程

服务器侧的预报发布大致是：

1. 生成新的 `worknx_summary_*`、`wrf_montage_*` 或 `airport_yunnan_*` 目录。
2. 写入 PNG 图、普通 WebP、小尺寸 `.preview.webp` 和必要的 `manifest_fragment.json`。
3. 上传 PNG/WebP/preview WebP 到 OSS，并确认公共 URL 可读。
4. 运行 `tools/build_forecast_catalog.py` 生成 `data/current/forecast-runs.json`。
5. 只保留每类产品最近 5 个起报时次。
6. 只提交并推送 `data/current/forecast-runs.json` 等小清单文件。
7. GitHub Pages 自动发布，浏览器下一次读取 catalog 时看到新时次。

## 本地开发原则

本地改页面时，通常只改这些文件：

```text
app.js
styles.css
index.html
ningxia/index.html
shangrao/index.html
airpots/index.html
assets/brand/*
tools/build_forecast_catalog.py
docs/*
README.md
```

本地不要随手提交整个 `data/current`。这个目录经常由 IAP 服务器自动更新，
`lazygit` 里看到的大量图片新增、删除、修改，很多只是服务器发布流和本地
旧工作树之间的差异。生成预报图目录已经被 `.gitignore` 忽略，日常发布
只需要提交 catalog JSON。

除非明确是在本机手动补图或修复 catalog，否则不要运行：

```bash
git add .
```

更稳妥的做法是只 add 明确要发布的代码或文档文件，例如：

```bash
git add app.js styles.css index.html ningxia/index.html shangrao/index.html airpots/index.html
git add tools/build_forecast_catalog.py docs/repository-structure.md
git add data/current/forecast-runs.json
```

如果只想发布 UI 或文档，不要把 `data/current` 混进去。

## 本地预览

在仓库根目录运行：

```bash
python3 -m http.server 5173
```

打开：

```text
http://127.0.0.1:5173/
```

不要直接双击 `index.html` 用 `file://` 打开；浏览器可能会阻止 JSON catalog 读取。

## 判断一个变动该不该推

可以推：

- 页面交互、样式、logo、文档；
- catalog 生成脚本；
- 少量明确需要作为静态 UI 或样例的资源。

谨慎推：

- `data/current/forecast-runs.json`；
- `data/current/manifest.json`；
- `data/current/maps/*`。

通常不该从本地推：

- 服务器已经自动维护的历史预报图；
- 本地旧目录里显示为删除的大批图片；
- 没确认来源的新旧时次混合数据。

## 当前推荐分工

- GitHub Pages：负责网页、前端逻辑、catalog 和小资源。
- OSS：负责实际大图加载，降低 GitHub Pages 压力。
- IAP 服务器：负责定时生成图、上传 OSS、更新 catalog、推送 GitHub。
- 本地电脑：负责改 UI、文档和发布脚本，不直接承担日常预报数据发布。
