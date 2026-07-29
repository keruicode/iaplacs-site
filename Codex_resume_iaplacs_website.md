# Resume：IAP-LACS 预报网站

更新时间：2026-07-26 CST

## 恢复本工作

最近的连续网站维护线程：

```bash
codex resume 019f9328-ea7c-7b92-a0f3-42cf58743cfc
```

若本机使用 `code` 别名：

```bash
code resume 019f9328-ea7c-7b92-a0f3-42cf58743cfc
```

- 线程 ID：`019f9328-ea7c-7b92-a0f3-42cf58743cfc`
- 会话日志：`/Users/xiaoxiaotu/.codex/sessions/2026/07/24/rollout-2026-07-24T16-06-00-019f9328-ea7c-7b92-a0f3-42cf58743cfc.jsonl`
- 工作目录：`/Users/xiaoxiaotu/_01_IAP/Website`

## 2026-07-26：三类全国图原生地理刻度修复

- 根因：`pmTickMarkDisplayMode="Always"` 的 MapPlot 内建刻度会覆盖
  `gsnMajorLonSpacing`/`gsnMajorLatSpacing` 的预期间隔，导致纵轴出现 5°
  加密标签；旧版图还依赖 ImageMagick 的人工坐标文字，位置与刻度脱节。
- `tools/rain_worknx_national_hour_bjt.ncl` 现在在
  `CylindricalEquidistant` MapPlot 内用 `tmXBMode="Explicit"` 与
  `tmYLMode="Explicit"` 指定真正的地理坐标：经度
  75/90/105/120/135°E、纬度 20/30/40/50°N。标签、主刻度与地图投影同源，
  未使用图像后期坐标文字。
- 仅保留底部和左侧的有标签主刻度；顶/右轴和四边子刻度均关闭。明确设置主
  刻度长度和粗细，避免 6×6 拼图裁切后刻度不可见。
- 代码提交：`93a5d9d Use geographic national tick coordinates`；天河完成强制
  重渲染、WebP 优化、catalog 更新和推送：`d3998fd Publish Tianhe forecasts
  worknx_summary_2026072518 airport_yunnan_2026072512 shangrao_2026072506`。
- 已从天河直接取回并视觉检查宁夏、云南机场、上饶三张最终全国 PNG：数值仅为
  指定的五个经度和四个纬度，且所有坐标标签由 NCL 地理刻度绘制。
- 验证通过：`git diff --check`、`bash -n tools/render_worknx_national_overview.sh
  tools/tianhe_publish_forecast_to_github.sh`；天河生产发布器成功结束并释放锁；
  三张线上 PNG 以 `?v=d3998fd` 访问均为 HTTP 200，最后修改时间为
  2026-07-26 16:31:53 CST。

## 当前状态

- 网站为 GitHub Pages 静态站；所有页面当前强制默认使用天河 catalog：`data/tianhe/current/forecast-runs.json`。
- “寰”来源仍保留在 `data/current/forecast-runs.json`，作为原 IAP 侧的备用/历史链路；其图件通常由 OSS 提供。
- 天河生产 checkout 是 `/fs2/home/junzhang/kerui/.iaplacs-site`，每 15 分钟自动检查完整 WRF、渲染图件、更新 `data/tianhe/current/` 并推送 GitHub。
- 当前网页服务：宁夏 `WORK_nx`、云南机场 `WORK_yn`、上饶 `WORK`；`WORK_tc` 不上网站，仅可生成降水精简备份。
- 网站每产品族保留 5 个时次；完整 WRF 默认不删除，cron 必须保持 `IAPLACS_TIANHE_DELETE_COMPLETED_MODEL_RUNS=0`。

## 本次整理

- 删除早期 Step 0 方案、旧 Tianhe 账号迁移说明、旧 OSS/IAP 部署说明及重复的英文运行记录。
- 新增 `docs/寰与天河运行维护手册.md`，集中说明两条链路、目录、cron、保留规则、检查和故障处理。
- 精简 `README.md`，只保留项目定位、本地预览和维护手册入口。
- 保留全部运行代码和可复用备用脚本；本次未删除生产脚本或预报数据。

## 重要文件

- `docs/寰与天河运行维护手册.md`：唯一的日常中文维护说明。
- `tools/tianhe_publish_forecast_to_github.sh`：天河主发布器。
- `tools/install_tianhe_publisher_cron.sh`：安装/刷新天河 cron。
- `tools/build_tianhe_forecast_catalog.py`：生成天河 catalog。
- `tools/build_forecast_catalog.py`：生成寰/IAP catalog。
- `app.js`：数据源选择、catalog 刷新、预览和下载逻辑。

## 验证

本次文档整理已通过：

```bash
node --check app.js
bash -n tools/tianhe_publish_forecast_to_github.sh
python3 -m py_compile tools/build_tianhe_forecast_catalog.py
git diff --check
```

四项命令均返回成功；Markdown 文件已收敛为本 Resume、`README.md` 和中文维护手册三份。

最近已知生产 catalog 时间为 2026-07-26，天河数据位于 `data/tianhe/current/`。如发现网站没有新时次，先在天河执行：

```bash
cd /fs2/home/junzhang/kerui/.iaplacs-site
tools/tianhe_publish_forecast_to_github.sh --dry-run
tail -n 120 /fs2/home/junzhang/.iaplacs-tianhe/logs/github-publisher.log
```

## 已知注意事项与下一步

- 不要删除 `/fs2/home/junzhang/kerui/.iaplacs-site`；它是正在运行的生产 checkout。
- 不要强行发布文件仍在增长或未满足稳定条件的 WRF 输出。
- 不要用 `git add .`，尤其不要将服务器生成图件或本地缓存混入网页代码提交。
- `.gitignore` 中 `.tmp` 的未提交修改为用户已有改动，保持不动。
- 如果需要恢复寰为页面默认来源，同时修改四个入口页的 `data-default-source`，并按维护手册确认 IAP/OSS catalog 与图件都已更新。
