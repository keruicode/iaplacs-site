# iaplacs.xyz 网站建设 Step 0 方案

更新时间：2026-07-09 22:10 CST

## 当前目标

域名 `iaplacs.xyz` 已购买。目标是逐步搭建一个科研所风格、现代、沉稳的天气预报/数据展示网站，后续形态接近睿图类天气预报服务，但重点突出 IAP-LACS 的科研数据、模式结果和可信更新链路。

## 推荐总体架构

第一阶段不要直接暴露 IAP 数据服务器。推荐拆成三层：

1. 数据生产层：IAP 服务器保留模式输出、观测数据、后处理脚本。
2. 发布层：把原始大文件处理成 Web 友好的 `manifest.json`、压缩 JSON、PNG/WebP 图片、地图瓦片或小型 GeoJSON。
3. Web 服务层：公网服务器运行 Nginx + 静态前端，必要时再加 FastAPI API。域名 `iaplacs.xyz` 解析到这一层。

如果 IAP 服务器本身有公网 IP、可以开放 80/443，并且单位允许对外提供服务，可以三层放在同一台服务器。但从安全和长期维护看，更稳妥的是：IAP 服务器只负责生产和推送，公网服务器负责展示。

## 第一阶段 MVP

目标：让 `https://iaplacs.xyz` 稳定访问一个最小可用站点，并能显示一批自动更新的数据产品。

建议组件：

- Web 服务器：Nginx。
- 前端：Vite + React 或 Next.js 静态导出。MVP 阶段优先 Vite + React，部署简单。
- 地图：MapLibre GL 或 Leaflet。
- 图表：ECharts。
- 数据文件：`public/data/current/manifest.json` 作为入口。
- 更新机制：IAP 服务器定时生成新目录，校验通过后原子切换 `current`。
- 定时任务：Linux `systemd timer` 优先，`cron` 也可。

推荐目录结构：

```text
/srv/iaplacs-site/
  app/                  # 前端构建产物
  data/
    releases/
      20260709_0800/
        manifest.json
        maps/
        stations/
        charts/
    current -> releases/20260709_0800
  logs/
```

前端只读 `data/current/manifest.json`，这样一次更新失败不会影响上一版在线产品。

## 域名和合规路径

1. 先确认公网入口 IP：公网服务器 IPv4 地址。
2. 在阿里云云解析 DNS 中添加记录：
   - `@` A 记录 -> 公网 IPv4。
   - `www` A 记录 -> 公网 IPv4，或者 CNAME 到 `iaplacs.xyz`。
   - TTL 可以先用 600 秒，方便调试。
3. 如果服务器在中国内地并对外提供网站服务，需要先完成 ICP 备案，再正式解析上线。
4. HTTPS 证书在 HTTP 能访问后申请。常规方案是 Certbot + Nginx。
5. ICP 备案后按要求完成公安联网备案，并在网页底部展示备案号。

参考官方页面：

- 阿里云云解析 DNS 添加解析记录：https://help.aliyun.com/zh/dns/pubz-add-parsing-record
- 阿里云备案服务：https://beian.aliyun.com/
- 全国互联网安全管理服务平台：https://beian.mps.gov.cn/
- Certbot Nginx 证书说明：https://certbot.eff.org/instructions?ws=nginx&os=snap

## 数据发布规范

每次更新生成一个发布目录，至少包含：

```json
{
  "site": "IAP-LACS Forecast",
  "run_time": "2026-07-09T08:00:00+08:00",
  "published_at": "2026-07-09T10:30:00+08:00",
  "products": [
    {
      "id": "precip_24h",
      "title": "24小时累计降水",
      "type": "image_sequence",
      "unit": "mm",
      "files": ["maps/precip_24h_f024.webp"]
    }
  ]
}
```

原则：

- 原始 NetCDF、GRIB、MICAPS 不直接给浏览器加载。
- 网页端优先加载小体积、明确时间戳、明确单位的数据。
- 所有产品都写入 `run_time`、`valid_time`、`lead_time`、`source`。
- 更新脚本先写到临时目录，全部检查通过后再切换 `current`。
- 保留最近 7-30 次发布，方便回滚和对比。

## 服务器初检清单

下一步需要在目标服务器上确认这些信息：

```bash
hostnamectl
uname -a
ip -4 addr
curl -4 ifconfig.me
ss -tulpn | grep -E ':80|:443'
df -h
free -h
```

还需要确认：

- 服务器是否有公网 IP。
- 单位是否允许开放 80/443。
- 当前系统是 Ubuntu、CentOS、Rocky、Debian 还是其他。
- 数据所在路径、格式、更新频率。
- 希望第一版展示哪些产品：降水、雷达、卫星、温度、风场、模式预报、站点实况等。

## 产品和视觉方向

第一屏不做营销页，直接做可用预报工作台：

- 顶部：IAP-LACS 标识、产品时间、更新状态、数据源。
- 左侧或顶部：产品切换、区域、时效、图层。
- 主区域：地图/预报图，支持时效播放。
- 右侧：关键指标、站点曲线、预警/说明。
- 底部：备案号、数据说明、联系方式。

视觉风格：

- 颜色：冷静中性底色，数据色标承担视觉重点，避免花哨渐变。
- 布局：密度适中，适合科研人员反复查看。
- 交互：时间轴、图层开关、区域选择、下载图片/数据。
- 文案：克制、准确，避免夸大预报能力。

## 下一步建议

第一步先确定公网部署路径：

1. 如果 IAP 服务器可公网访问：在 IAP 服务器上部署 Nginx 测试页。
2. 如果 IAP 服务器不可公网访问：买或使用一台公网 ECS/轻量服务器，IAP 服务器定时推送数据到公网服务器。
3. 如果短期只想快速展示：先用阿里云 OSS/CDN 或 ECS 放静态站点，数据由 IAP 服务器定时上传。

我建议优先选第 2 种：公网 Web 服务器和 IAP 数据服务器分离，后续安全、备案、迁移、扩展都更可控。

## 当前轻量路线：GitHub Pages 静态站

用户当前倾向：先用 GitHub Pages 做网站，OSS 可用可不用，核心要求是图片能流畅加载。

这条路线可作为第一版 MVP：

1. GitHub Pages 托管前端页面、`manifest.json` 和少量优化后的图片。
2. IAP 服务器定时生成 Web 资源：WebP/PNG 预报图、小型 JSON、产品清单。
3. 定时任务把生成结果提交到 GitHub 仓库，或上传到对象存储后只更新 `manifest.json`。
4. `iaplacs.xyz` 绑定 GitHub Pages 自定义域名。

容量判断：

- 图片数量少、访问量低：图片直接放 GitHub Pages 仓库最简单。
- 图片多、更新频繁、访问量上来：页面仍放 GitHub Pages，图片拆到对象存储/CDN。
- 如果使用阿里云中国内地 OSS 并绑定自定义域名，仍要关注 ICP 备案；如果使用 GitHub Pages 或境外对象存储，通常不走阿里云备案服务码。

建议第一版图片规范：

- 预报图优先 WebP，必要时保留 PNG 备用。
- 单张主图尽量控制在 300 KB - 800 KB，复杂地图可放宽到 1.5 MB。
- 宽度按展示需求导出，桌面主图常用 1600-2200 px，缩略图另存。
- 文件名带模式起报时间、变量、时效，例如 `20260709_0800_precip_f024.webp`。
- `manifest.json` 只指向当前有效产品，历史归档先少量保留，避免仓库快速膨胀。

推荐先做：

```text
iaplacs.github.io 或 github 用户/组织 Pages 仓库
  index.html / React app
  data/current/manifest.json
  data/current/maps/*.webp
```

后续如果图片加载慢，再升级到：

```text
GitHub Pages: 前端页面 + manifest.json
对象存储/CDN: 大量图片、瓦片、历史产品
```
