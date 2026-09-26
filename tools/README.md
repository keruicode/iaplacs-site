# 脚本入口

本目录保留当前脚本的原文件名和相邻关系，避免破坏服务器部署、脚本互调和相对路径。
本地是源码；寰上的正式运行目录仍为 `/data1/elpt_2022_00083/kerui/Website`。
不要在 Mac 上直接执行发布器，也不要把整个本地目录连同历史文件覆盖到生产目录。

## 绘图

| 用途 | 文件 |
| --- | --- |
| 中国中东部/宁夏及新疆共用入口 | `render_worknx_ningxia_overview.sh` |
| 宁夏/新疆区域降水 | `rain_worknx_ningxia_hour_bjt.ncl` |
| 大区域小时降水、冰雹和12/24小时累计降水 | `rain_worknx_national_hour_bjt.ncl` |
| 云南机场绘图入口 | `render_worknx_yunnan_airports_overview.sh` |
| 云南区域降水 | `rain_worknx_yunnan_airport_hour_bjt.ncl` |
| 云南/新疆气温、风场和时序 | `render_yunnan_airport_aviation_preview.py` |
| 机场点降水提取 | `extract_yunnan_airport_precip.py` |
| 图件时间序列检查 | `validate_hourly_panel_sequence.py` |
| 拼图工具 | `make_wrf_montages.sh` |
| 边界输入 | `SHP/` |

`render_yunnan_airport_aviation_preview.py` 虽名为 preview，仍是生产依赖，不能当作旧试验删除。
`extract_tianhe_precip_backup.py` 是仍可手动使用的降水提取工具，因此保留在这里。

## 发布与运维

- 全站检查：`audit_iap_forecast_publication.sh`。
- 中国中东部：`publish_worknx_ningxia_to_github.sh`。
- 云南：`publish_worknx_yunnan_airports_to_github.sh`、`publish_workyn_yunnan_airports_if_new.sh`。
- 新疆：`publish_workxj_xinjiang_to_github.sh`。
- 目录清单：`build_forecast_catalog.py`、`attach_hourly_frames_to_catalog.py`。
- 上传：`publish_worknx_summary_to_github.sh`、`publish_hourly_panels_to_oss.sh`、`publish_airport_aviation_to_oss.sh`。
- 实况：`fetch_cma_24h_precipitation.py`、`publish_cma_24h_observations.sh`。
- 备份、SSH 恢复、OSS 保留策略：`backup_iap_runtime.sh`、`ensure_iaplacs_ssh_state.sh`、`run_iap_oss_retention.sh`、`prune_iaplacs_oss.sh`。
- 定时安装器：`install_iap_*.sh`；清晨产品：`publish_bjt06_partial_forecasts.sh`。

原上饶的兼容入口和共享工具仍保留，未因为文件名含 wrf/shangrao 就删除。
明确退役的天河过渡链路和一次性任务在 [历史](archive/README.md)。

新增脚本文件和目录统一使用英文。寰上当前入口集中在`Website/scripts/`，历史脚本在`Website/archive/scripts/`。`runtime_paths.sh`区分脚本位置和图件所在的运行根目录，避免移动脚本后改变输出位置。
