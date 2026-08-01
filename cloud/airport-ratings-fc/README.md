# 机场预报评分共享存档：阿里云部署与维护手册

本目录是 `https://iaplacs.xyz/airpots/` 中三家云南机场预报评分的后端源码和部署记录。

它解决的是静态 GitHub Pages 网站无法安全写入共享数据的问题：访客点击“准 / 不准 / 一般”后，
评分立即写入阿里云 OSS；其他地区、其他网络中的访客随后打开同一预报时次时，会读取并看到相同的汇总结果。
全程不要求访客登录 GitHub，也不在网页中放置 GitHub Token、阿里云 AccessKey 或其他可写密钥。

## 1. 当前生产配置

| 项目 | 当前值 |
| --- | --- |
| 阿里云地域 | 中国（香港） |
| Function Compute 函数 | `airport-ratings` |
| 运行环境 | Python 3.10 |
| 处理程序 | `index.handler` |
| 函数 RAM 角色 | `iaplacs-ratings-oss-role` |
| 自定义策略 | `iaplacs-ratings-oss-policy` |
| HTTP 触发器 | `ratings-http` |
| 公网接口 | `https://airport-ratings-klxqryorbb.cn-hongkong.fcapp.run/` |
| OSS bucket | `iaplacs-forecast-images-hk` |
| OSS 内部 endpoint | `https://oss-cn-hongkong-internal.aliyuncs.com` |
| 评分对象前缀 | `iaplacs/ratings/v1/` |
| 允许调用网页 | `https://iaplacs.xyz`、`https://www.iaplacs.xyz` |

`fcapp.run` 是 Function Compute 分配的默认域名，适合当前过渡阶段。阿里云控制台也会提示默认公网域名不建议长期生产使用。长期运行时，应创建并绑定例如 `ratings.iaplacs.xyz` 的自定义域名，随后只需将
`airpots/index.html` 中的 `data-airport-ratings-api-url` 改成新 URL 并推送即可。

## 2. 架构和数据流

```text
访问者浏览器
  |  GET：读取全部汇总
  |  POST：提交或撤销自己的单项评分
  v
Function Compute：airport-ratings
  |  使用函数临时 STS 凭证，无长期 AccessKey
  v
OSS：iaplacs-forecast-images-hk/iaplacs/ratings/v1/
```

网页每个浏览器首次评分时会在 `localStorage` 创建一个随机 UUID。它只是匿名浏览器标识，作用是让同一浏览器对同一“数据源 + 起报时次 + 机场”保留一票；它不是用户账号，也不包含姓名、IP、位置或联系方式。

评分不写进一个公共 JSON 文件，而是每个浏览器保存一个独立小对象：

```text
iaplacs/ratings/v1/{source_id}/{run_id}/{airport_id}/{client_id}.json
```

示例：

```text
iaplacs/ratings/v1/huan/airport_yunnan_20260731_00/dehong_mangshi/
  20af9e34-7d9b-4b9f-b5d6-1552c6c0dcec.json
```

这样多名用户同时评分时不会互相覆盖。函数读出当前时次下所有对象，实时汇总 `准 / 不准 / 一般` 三种计数。再次点击已选项时，网页发送 `rating: null`，函数删除该浏览器对应的小对象，因此可以撤销评分。

## 3. 为什么不能直接从 GitHub Pages 写 GitHub

GitHub Pages 是纯静态网站。任何写 GitHub API 的 Token 如果放在前端 JavaScript 中，所有访客都能看到并可利用该 Token 修改仓库。因此此前的“存档至 GitHub Issue”只能打开草稿，仍要求用户登录并手动提交。

本方案把写入权限交给 FC 的 RAM 角色。浏览器只可访问受参数校验和来源限制的 HTTP 接口；函数自身只获得评分目录的最小 OSS 权限，无法读取、覆盖或删除预报图、网站目录和其他 OSS 文件。

## 4. 从零创建一次服务

以下步骤用于在新账号或发生迁移时重建。操作前确认 OSS bucket、FC 和 RAM 均选择**中国（香港）**地域或可互通地域；函数和 bucket 同地域时使用 OSS 内网 endpoint，速度更快且不走公网流量。

### 4.1 准备 OSS bucket

1. 进入阿里云 **对象存储 OSS** 控制台。
2. 使用现有 bucket `iaplacs-forecast-images-hk`，或在香港地域新建一个 bucket。
3. 不需要预先创建 `iaplacs/ratings/v1/` 目录。OSS 没有真实目录，首次写入对象时前缀会自动出现。
4. 评分对象不需要公开读；网页只访问 FC，FC 通过角色访问 OSS。预报图片原有的公开读取设置不受影响。

### 4.2 创建最小权限 RAM 策略

1. 进入 **访问控制 RAM** 控制台，打开 **权限策略**，选择 **创建权限策略**。
2. 选择 **脚本编辑**，策略名称填写 `iaplacs-ratings-oss-policy`。
3. 将 bucket 名称按实际情况替换，然后粘贴下列 JSON：

```json
{
  "Version": "1",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["oss:ListObjects"],
      "Resource": ["acs:oss:*:*:iaplacs-forecast-images-hk"]
    },
    {
      "Effect": "Allow",
      "Action": ["oss:GetObject", "oss:PutObject", "oss:DeleteObject"],
      "Resource": ["acs:oss:*:*:iaplacs-forecast-images-hk/iaplacs/ratings/*"]
    }
  ]
}
```

4. 保存策略。控制台有时会对 `ListObjects` 的 bucket 资源显示笼统提示；`ListObjects` 本身必须配置在 bucket 资源上，而对象的读写删权限必须限制在对象前缀上，上述组合是本服务所需的最小范围。

### 4.3 创建 RAM 角色并授权

1. 在 RAM 控制台进入 **身份管理 > 角色**，选择 **创建角色**。
2. 可信实体类型选择 **阿里云服务**，服务选择 **函数计算 FC**。
3. 角色名填写 `iaplacs-ratings-oss-role`。
4. 创建后进入该角色的 **权限管理**，点击 **精准授权**。
5. 选择 **自定义策略**，选中 `iaplacs-ratings-oss-policy`，确认授权。
6. 若提示 `EntityAlreadyExists.Role.Policy`，表示策略已经绑定，无需重复添加。

不要为该函数配置 `AdministratorAccess`、整 bucket 的 `oss:*`，或个人 AccessKey。函数运行时会自动获得短期 STS 凭证。

### 4.4 构建上传包

在本仓库根目录执行：

```bash
bash cloud/airport-ratings-fc/build_zip.sh
```

输出文件为：

```text
cloud/airport-ratings-fc/dist/airport-ratings-fc.zip
```

当前阿里云 FC Python 3.10 运行时已实测包含 `oss2`，生产 ZIP 因此只包含 `index.py`。`requirements.txt` 只为本地 Python 环境保留。如果未来函数日志出现 `ModuleNotFoundError: oss2`，应在 FC 的 Linux 构建环境或层中安装 `oss2`，不要把 macOS 本机编译出的依赖直接打进 Linux 函数包。

### 4.5 创建或更新 Function Compute 函数

1. 打开 **函数计算 FC** 控制台，地域选择 **中国（香港）**。
2. 选择 **云函数 > 函数列表 > 创建函数**。
3. 创建方式选择 Web 函数/事件函数均可，后续必须创建 HTTP 触发器；函数名填写 `airport-ratings`。
4. 运行环境选择 **Python 3.10**。
5. 请求处理程序填写 `index.handler`。
6. 执行超时时间设置为 `10` 秒，内存 `512 MB` 即可。
7. 函数角色选择已有的 `iaplacs-ratings-oss-role`。
8. 创建后进入函数 **代码**，选择 **上传代码 > 上传 ZIP**，上传第 4.4 步生成的 ZIP，并部署。

建议环境变量保持以下值；未填时 `index.py` 也会使用这些默认值：

```text
RATING_BUCKET=iaplacs-forecast-images-hk
OSS_ENDPOINT=https://oss-cn-hongkong-internal.aliyuncs.com
RATING_PREFIX=iaplacs/ratings/v1
```

函数代码中的机场、数据源和评分值均做了白名单校验：

```text
数据源：huan、tianhe
机场：dehong_mangshi、xishuangbanna_gasa、puer_lancang_jingmai
评分：accurate、inaccurate、fair
```

### 4.6 创建 HTTP 触发器

1. 进入函数 **触发器** 标签页，点击 **创建触发器**。
2. 触发器类型选择 **HTTP 触发器**。
3. 名称填写 `ratings-http`，版本选择 `LATEST`。
4. 请求方法只保留 `GET`、`POST`、`OPTIONS`；删除默认多出的 `PUT`、`DELETE`。
5. 保持 **禁用公网访问 URL = 否**，否则网页无法调用。
6. 认证方式选择 **无需认证**，然后创建。
7. 复制生成的**公网访问地址**，例如：

```text
https://airport-ratings-klxqryorbb.cn-hongkong.fcapp.run/
```

“无需认证”是为了让不登录任何账户的普通网站访问者可以评分。安全边界由四层共同组成：仅允许指定网页 Origin、严格白名单参数、每浏览器单对象、RAM 角色只允许访问评分前缀。仍应定期检查函数日志；如果出现恶意流量，可暂时在触发器中禁用公网访问或绑定自定义域名后通过网关增加限流。

## 5. 前端接入

机场页面在 `airpots/index.html` 的 `<body>` 上通过数据属性配置接口：

```html
data-airport-ratings-api-url="https://airport-ratings-klxqryorbb.cn-hongkong.fcapp.run/"
```

前端实现位于 `app.js`：

- `airportRatingClientId()`：生成并保存匿名 UUID；
- `ensureAirportRatings()`：打开页面或切换数据源/起报时次后 GET 汇总；
- `toggleAirportRating()`：评分或撤销时 POST；
- `renderAirportFeedback()`：展示当前浏览器的选中状态和所有访客的累计计数；
- `airportRatingStatusText()`：显示“正在同步评分”“正在自动存档”或“评分自动存档”。

修改接口地址、域名或 CORS 白名单后，务必同步更新这三处：

1. FC `index.py` 的 `ALLOWED_ORIGINS`；
2. FC HTTP 触发器的公网访问设置；
3. `airpots/index.html` 的 `data-airport-ratings-api-url`。

网页改动完成后递增 `styles.css`、`app.js` 的 query 版本号并推送，避免浏览器继续使用旧缓存：

```bash
git add airpots/index.html app.js styles.css
git commit -m "Update airport rating endpoint"
git pull --rebase origin main
git push origin main
```

## 6. 验证清单

### 6.1 本地静态检查

```bash
node --check app.js
python3 -m py_compile cloud/airport-ratings-fc/index.py
bash -n cloud/airport-ratings-fc/build_zip.sh
git diff --check
```

### 6.2 读取接口

将接口 URL 和起报时次替换为实际值：

```bash
curl --noproxy '*' -i \
  'https://airport-ratings-klxqryorbb.cn-hongkong.fcapp.run/?source_id=huan&run_id=airport_yunnan_20260731_00&client_id=00000000-0000-4000-8000-000000000001' \
  -H 'Origin: https://iaplacs.xyz'
```

应返回 `HTTP 200`、`Access-Control-Allow-Origin: https://iaplacs.xyz`，以及以下结构：

```json
{
  "source_id": "huan",
  "run_id": "airport_yunnan_20260731_00",
  "ratings": {
    "dehong_mangshi": {"accurate": 0, "inaccurate": 0, "fair": 0, "total": 0}
  },
  "viewer_ratings": {}
}
```

### 6.3 浏览器跨域预检

```bash
curl --noproxy '*' -i -X OPTIONS \
  'https://airport-ratings-klxqryorbb.cn-hongkong.fcapp.run/' \
  -H 'Origin: https://iaplacs.xyz' \
  -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: content-type'
```

预期为 `204 No Content`，并包含：

```text
Access-Control-Allow-Origin: https://iaplacs.xyz
Access-Control-Allow-Methods: GET,POST,OPTIONS
Access-Control-Allow-Headers: Content-Type
```

### 6.4 端到端人工检查

1. 打开 `https://iaplacs.xyz/airpots/`，强制刷新网页。
2. 在“服务评价 > 预报评分”中选择一个机场的一项评分。
3. 页面应立即显示“正在自动存档”，随后恢复“评分自动存档”。
4. 用另一台设备或无痕窗口打开同一**数据源和起报时次**，应能看到对应选项的总数增加；另一台设备本身不会自动变成选中状态。
5. 在第一台设备再次点击同一选项，计数应回退；切换选项时，旧项减一、新项加一。

## 7. 日常运维和故障排查

### 评分无法同步

按以下顺序检查：

1. 浏览器开发者工具 Network 中评分接口是否返回 `200`；
2. 请求是否来自 `https://iaplacs.xyz`，而非本地 `http://127.0.0.1`。本地预览不在 CORS 白名单中，不能直接测试跨域写入；
3. FC 控制台 **日志** 是否有 `airport ratings API failed`；
4. FC **配置 > 权限** 中函数角色是否仍为 `iaplacs-ratings-oss-role`；
5. RAM 角色是否仍绑定 `iaplacs-ratings-oss-policy`；
6. 检查 OSS bucket 名称、endpoint 和 `RATING_PREFIX` 环境变量是否一致；
7. 检查触发器是否启用、是否仍允许公网 URL、认证方式是否为无需认证。

### 返回 403 origin_not_allowed

这是 FC 正在拒绝未知来源。检查浏览器请求的 `Origin`，并在 `index.py` 的 `ALLOWED_ORIGINS` 中显式加入需要的 HTTPS 域名，重新构建 ZIP、上传并部署。不要使用 `*` 放开所有来源。

### 返回 500 internal_error

优先查看 FC 请求 ID 对应的函数日志。常见原因是 RAM 策略被移除、bucket/endpoint 填错、运行时缺少 `oss2`，或函数与 OSS 不在预期地域。

### 清理历史评分

评分按起报时次存放，会随预报目录增长。推荐在确认不再需要旧时次评分后，在 OSS 控制台只删除：

```text
iaplacs/ratings/v1/{huan|tianhe}/{旧_run_id}/
```

不要删除 `iaplacs/` 下其他预报图片和目录。若要自动清理，可对 `iaplacs/ratings/` 配置 OSS 生命周期规则，例如保留 90 天；配置前先确认历史评分是否需要科研归档。

## 8. 安全边界和限制

- 本系统是匿名评价，不是身份认证或防刷票系统。清除浏览器站点数据、换浏览器或脚本构造不同 UUID，都可形成新的匿名评分。
- 每次 GET 都会列举并读取该起报时次下的评分对象。当前规模下足够简单可靠；若将来每个时次达到大量评价，应改为数据库或定期聚合 JSON。
- API 只允许指定 Origin 的浏览器跨域读取；接口本身是公网 URL，命令行仍可访问。因此对象中不得存放姓名、电话、IP、精确位置或其他敏感信息。
- Git 仓库只保存函数源码和网页代码，不保存评分数据。评分数据在 OSS 中，便于独立备份、生命周期管理和删除。
- 新增机场、数据源或评分等级时，要同时更新 `index.py` 白名单和 `app.js` 的 `AIRPORT_RATING_TARGETS` / `AIRPORT_RATING_OPTIONS`，再重新部署函数与网页。
