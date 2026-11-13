# Supercooled Liquid Water Path Preview

## Release Preparation (2026-11-14)

当前为待上线版本，**未修改 IAP 生产脚本、crontab、线上目录或 OSS**。下文首轮试验记录继续保留。

| 服务 | 模式目录 | 区域按钮 | 大范围按钮 |
| --- | --- | --- | --- |
| 中国中东部 | WORK | 宁夏区域 | 中国中东部 |
| 中国西南部 | WORK_yn | 云南区域 | 中国西南部 |
| 中国西北部 | WORK_xj | 新疆区域 | 中国西北部 |

左侧分别增加“过冷云水路径”和“过冷雨水路径”，不增加总液水产品。
每个产品提供上述两个范围、逐时、拼图及原图下载。云南沿用默认逐时，宁夏、新疆默认拼图。
12时次采用3列4行，其余数量自适应，不补造缺失时次。时间为瞬时有效时间，统一BJT；不使用降水累计区间标题。

区域数据优先同一起报 d02；不存在 d02 时使用 d01 截取。宁夏保持宁夏范围；云南、新疆有 d02 时按嵌套域范围。
大范围始终单独使用 d01，不将 d02 的小图改名冒充大范围，不重复叠加嵌套数据。东侧显示上限沿用145°E。
存在但损坏或时间不完整的 d02 会报错等待下一轮，不偷偷降级。两域起报和选出的有效时刻必须一致。

### Prepared Code

- `tools/supercooled_water_path.py`：已验证的垂直积分和热力重建。
- `tools/supercooled_wrf_io.py`：维度/单位检查、分块读取、输入哈希和质控记录。
- `tools/render_supercooled_water_path.py`：一次计算两种路径，绘制两个区域和逐时/拼图。
- `tools/supercooled_contract.py`：两产品、两区域、相同有效时刻和图件存在性的完整性门禁。
- `tools/publish_supercooled_water_path.sh`：完成态判断、锁、缓存、上传成功回执及只绘图入口。
- `tools/supercooled_settings.sh`：默认关闭，指定首次起报后才允许自动发布。
- 本地已准备目录构建、OSS发布器、审计任务及 `app.js` 的接口；尚未部署到生产。

完整manifest最后原子替换。图件使用内容签名区分的目录；源文件或脚本变化会重新生成。
只上传当前一代的图件，不把历史试验目录一起上传。上传失败不写成功回执，下次审计可重试。
新产品检查排在现有产品检查之后，避免先处理新增诊断而耽误原有业务。
色标仍为试验分级，不是积冰等级；缺测在数据中保留NaN，在图上显示白色。

### Enable Later, Not Now

1. 核对并备份生产 `scripts/` 与 server02 发布仓库。将上述新文件和本轮涉及的
   `runtime_paths.sh`、`audit_iap_forecast_publication.sh`、`publish_airport_aviation_to_oss.sh`
   部署到 IAP `scripts/`。保持 `.runtime-root`、字体和SHP引用正确，不覆盖其他人的修改。
2. 先把目录构建所需的 `build_forecast_catalog.py`、`check_diagnostic_catalog.py`、
   `supercooled_contract.py` 同步到 server02 发布仓库及 GitHub；否则旧目录构建器不能接入新产品。
   GitHub 尚未同步本轮任何源码，启用时必须完成这一步。
3. 先用下面的 `--render-only` 跑完整起报。此入口自动进入 `plot` 作业，**不要在登录节点直接运行Python**。
4. 正式启用时才建立 `Website/state/supercooled-start-run`，内容为首次上线的UTC起报，例如
   `20261112_18`，末尾换行。没有此文件时发布入口直接返回，不启动Python、Slurm或网络传输。
   只处理指定起报及以后的批次，避免无意补画全部历史。
5. 在 `index.html`、`airpots/index.html`、`xinjiang/index.html` 的 `<body>` 添加
   `data-supercooled-paths="enabled"`，更新 `app.js` 的版本参数，审核后再提交上线。
   当前三个正式HTML均没有该属性，新产品默认隐藏。沿用原有2分钟调度，不新增并行cron。
6. 核对三个服务目录都包含两个产品、每个产品两个范围，并抽查OSS图片及下载链接。
   正式上传事务本轮没有执行，不能将试图成功说成已经完成线上发布验证。

只绘图例子（需完成部署后运行；输出应使用独立目录）：

```bash
bash /data1/elpt_2022_00083/kerui/Website/scripts/publish_supercooled_water_path.sh \
  --profile yunnan --run 20261112_18 --render-only \
  --output /data1/elpt_2022_00083/kerui/Website/.tmp/supercooled_review_yunnan_20261112_18
```

将 `--profile` 换为 `ningxia` 或 `xinjiang` 可测试对应服务。
`--count` 限制帧数的研究预览不会标记为可发布，目录门禁会拒绝将它当作完整批次上线。
停止未来发布时移走 `state/supercooled-start-run`；隐藏按钮则移除三个HTML上的启用属性。
移走开关不会取消已经在运行的作业，也不会撤回已发布目录；如需立即停止，应另外核对并取消本产品对应的作业。

### Isolated Verification

生产外的测试目录为本地及IAP的 `.tmp/supercooled_release_prep_20261113/`。
修改前核心备份：本地 `.tmp/supercooled_preparation_before_20261113.tar.gz`。
首轮 `plot 40471220` 在 `a3107n13` 完成，退出0，耗时4分35秒，21项测试通过。
真实输入为宁夏 `WORK/2026111300`、云南和新疆各自 `2026111218`。
三个服务各选2个时刻，均生成两产品、两范围，并验证缓存复用。图件已下载检查；没有下载完整WRF。
随后作业 `40472050` 在 `a3107n13` 正常结束，退出0，耗时9分20秒，21项测试再次通过。
完整云南只绘图入口成功：两产品、两范围各12时次，拼图3列4行；宁夏、新疆修订坐标后的两时次图也完成。
完整云南拼图已下载目视检查，未触发上传。
本地默认关闭、网页产品筛选、调度回归及shell语法检查通过。尚未完成浏览器端完整视觉验收或真实OSS发布验收。

## Status

2026-11-13：资料调研与独立试图，不是已上线产品。不修改模式、生产绘图、网站目录、OSS 或定时任务。
试验源码与结果位于 `.tmp/supercooled_path_20261113/`，已由现有 `.gitignore` 排除。

首轮作业 `40467078` 已完成（计算节点 `a3110n05`，约60秒，退出0）。8项解析/边界测试通过，`py_compile` 通过，新增源码 Black/Ruff 检查通过（Ruff 的 E402 因科学导入前执行计算节点保护而显式豁免）。已下载六张400dpi PNG、两份 NetCDF 与各自 manifest，目视检查云南总量、新疆云水与雨水图。没有下载完整 wrfout。

| 样本 | 云水路径域均值 | 雨水路径域均值 | 合计域均值 | 合计最大值 |
| --- | ---: | ---: | ---: | ---: |
| 云南 d02 | 1.154 | 1.272 | 2.426 | 6117.277 |
| 新疆 d02 | 45.455 | 0.887 | 46.343 | 4635.353 |

单位均为 g/m²。两者起报均为2026-11-13 02:00 BJT，有效时间20:00 BJT；只代表这一时刻，不是气候结论或观测验证。个别值超过试验色标上限，图上使用扩展颜色，数值没有截断。

云南有1个缺测柱，检查记录显示输入 QVAPOR 最小值为约 −5.17e−15 kg/kg，触发了严格的非负水汽检查；未将其当作无云。后续可按与云雨水一致的舍入容差处理并计数，本轮保留原始试验。新疆无缺测柱。低于−40℃的最大合计贡献分别约0.00656和0.15658 g/m²，未主导本时刻图面。日志中的中文粗体字体回退警告已保留；代表图标题可读，没有缺字或裁切。

本地结果：`yunnan_40467078/` 和 `xinjiang_40467078/`，位于上述试验目录下。远端同名试验目录位于 `/data1/elpt_2022_00083/kerui/Website/.tmp/`。

## What “Path” Means

这里的“路径”不是粒子运动轨迹，也不是某一层的含水量。它是一个地面格点上方，沿垂直方向积分得到的液态水质量，除以该格点面积。

- 某层液态水含量：g/m³。
- 柱积分液水路径：g/m²。
- 例：一层平均云水含量为 0.2 g/m³，厚 500 m，它贡献 100 g/m²；另一层贡献 50 g/m²，整柱就是 150 g/m²。
- 这是**某个时刻的柱内存量**，不是过去一小时落到地面的降水，也不随预报时间累计。

Turner 等（2016）将 LWP 定义为液态水含量的垂直积分；WRF-Solar 原始代码也通过密度、层厚和水成物混合比进行积分。[文献](https://journals.ametsoc.org/view/journals/atot/33/1/jtech-d-15-0074_1.xml)，[WRF 原始代码](https://github.com/wrf-model/WRF/blob/master/phys/module_diag_solar.F)。前者本次检索可读摘要/引言摘录，直接页面返回403，不声称已阅读全文。

## Three Fields

本试验明确区分云水与雨水，不假定所有文献的 LWP 都包含雨水。

这种分开诊断有文献与模式实现依据：NASA NU-WRF 用户手册列出 cloud liquid water path 与 rain water path；Qiu 等（2026）的 WRF 近LES试验也分别比较云液水路径和雨水路径。两者都不是机场积冰分级标准。[NU-WRF 手册](https://nuwrf.gsfc.nasa.gov/sites/default/files/docs/nuwrf_userguide_v11.pdf)，[Qiu 等，2026，图3](https://acp.copernicus.org/articles/26/1769/2026/acp-26-1769-2026.html)。前者本次核对了检索可读的版本变更条目，全文下载超时。

\[
S_c = 1000\sum_k \rho_{d,k}q_{c,k}\Delta z_k\,\mathbf{1}(T_k<273.15),
\qquad
S_r = 1000\sum_k \rho_{d,k}q_{r,k}\Delta z_k\,\mathbf{1}(T_k<273.15).
\]

\[
S_{\mathrm{liquid}}=S_c+S_r.
\]

| 图件 | 模式变量 | 单位 |
| --- | --- | --- |
| 过冷云水路径 | QCLOUD | g/m² |
| 过冷雨水路径 | QRAIN | g/m² |
| 总过冷液水路径 | 两者相加 | g/m² |

`q` 是 kg/kg **干空气**，`rho_d` 是 kg/m³，`dz` 是 m，乘 1000 转为 g/m²。三个图采用同一个色标，便于直观比较，不分别自动缩放。

只统计模式已解析的 QCLOUD/QRAIN，不加水汽、冰、雪、霰或雹，也没有额外重建积云参数化中的未解析液水。QCLOUD/QRAIN 是模式类别，不等于实测粒径分档，不能直接将 QRAIN 图称为 SLD 预警。

## WRF Reconstruction

读取 `QCLOUD, QRAIN, QVAPOR, T, P, PB, PH, PHB, XLAT, XLONG, Times`。
先验证单位、维度和 `T` 为干扰动位温的描述，不能将 `T` 原值当摄氏温度，也不能以 T2 判断整根气柱。

\[
p=P+PB,\quad \theta=T_{\mathrm{WRF}}+300,\quad
T_K=\theta(p/100000)^{R_d/c_p},
\]
\[
\rho_d=\frac{p}{R_dT_K(1+q_vR_v/R_d)},\qquad
\Delta z_k=\frac{(PH+PHB)_{k+1}-(PH+PHB)_k}{g}.
\]

这里 PH/PHB 位于层界面，必须做相邻界面差分，不能把层中心高度直接当层厚。干空气密度与干空气混合比保持一致，不能直接混用含水空气密度。

常数采用标准 WRF 值：`Rd=287`, `Rv=461.6`, `cp=3.5*Rd`, `g=9.81`。
[WRF 输出说明](https://www2.mmm.ucar.edu/wrf/site/documentation/users_guide/output.html)，[常数源码](https://github.com/wrf-model/WRF/blob/master/share/module_model_constants.F)。WRF-Solar 的积分权重还显式处理干/湿空气基准，不是简单 `sum(q)`。

## Temperature and Missing Data

1. 主图用每个模式层中心的 `T < 0℃`，累加全部符合条件的层。暖层不计入，逆温上下的冷层可以同时计入。
2. 不默认把所有低于 −40℃的液水删去；另外输出 `<−40℃` 的贡献，用于判断模式相态是否可疑。若要采用 −40至0℃窗口，应作为另一明确命名的诊断，不悄悄修改“全部过冷液水”的定义。
3. 温度、密度或层厚缺测/无效，整柱标为缺测；冷层中的水成物无效时，对应分量及总量标缺测，不把部分积分伪装成完整值。
4. `[-1e-10,0)` kg/kg 的微小负水量按数值舍入归零并记录，明显负值标缺测。没有按颜色或固定大值阈值截断液水。
5. 图面缺测用白色，NetCDF 和 manifest 保留缺测标记及数量；白色本身不能用于区分“无水”和“缺测”。
6. 层中心温度对整层分类是第一版离散近似。跨零度层没有做层内温度插值，后续可在敏感性试验中检查；此处不额外平滑或改变原始网格。

## Plot Design

- 首轮用云南、新疆已完成的 `2026111218`、d02；选择预报 +18 h，超过12小时 spin-up。
- 时间标题是瞬时有效时间，不写降水式的 `19–20时` 区间。
- 范围覆盖真实 d02 经纬度范围，省界和机场沿用已有绘图函数，右侧竖直色标、白底、400 dpi。
- 试验色标：`1, 5, 10, 25, 50, 100, 200, 400, 800, 1600 g/m²`，低于1为白色，大于1600有最高级扩展颜色。数据本身不截断。
- **该分级只是试图建议，不是国家业务标准，也不是轻/中/重积冰阈值。** 定稿前依据不同区域和多个时次的分布调整。
- 后续若接入网站，可像降水一样提供区域 d02 与大范围 d01、逐时与拼图；两域各自独立积分，不拼接或重复累加嵌套气柱。本轮未实现发布。

## Aviation Interpretation and Sources

路径图只能回答“这个位置上方有多少过冷液水”，不能回答飞机在哪个高度会结冰、结冰多快，也不能当作地面冻雨诊断。高度、温度、粒径、遭遇时间等仍很重要。[FAA 气象说明](https://www.faa.gov/air_traffic/publications/atpubs/aip_html/chap7_section_1.html)。

NASA 的资料说明，大过冷水滴既可能与暖层融化后的降水有关，也可能由液滴碰并形成，而且可仅存在于高空。因此，过冷雨水路径值得与过冷云水路径分开看，不能仅靠地面有没有降水判定。[NASA SLD](https://aircrafticing.grc.nasa.gov/1_1_2_5.html)。

正式积冰产品如 NCAR CIP/FIP 会提供三维的概率、强度与大过冷水滴潜势，并融合多种资料。这里的水路径只是一个模式诊断，不冒充这类业务产品。[NCAR CIP/FIP](https://ral.ucar.edu/solutions/products/icing-products-cipfip-operational)。

Ricaud 等（2020）的南极研究表明，模式中液/冰相态分配会显著影响 LWP；因此图看起来弱或为空，可能是微物理液水不足，并非绘图错误。该个例并不能给云南/新疆提供直接校准。[ACP 论文](https://acp.copernicus.org/articles/20/4167/2020/)。

## Reproducibility

- `liquid_path.py`：纯数组热力重建及柱积分。
- `test_liquid_path.py`：解析算例、暖层排除、缺测、负值、层厚及密度基准检查。
- `preview.py`：验证 WRF 元数据、分块读取单时刻、保存 NetCDF/manifest 和三张图。
- `test.slurm`：只允许计算节点；作业名 `plot`，1 CPU，线程池限制1，依次处理两地。
- 输入记录文件大小/mtime和实际读取字段的SHA256，而不是为取哈希再读完整的十几GB文件；代码哈希和色标配置记录在manifest。
- 输出目录带作业号，每次试验独立保留，不覆盖旧试验。不向网站/OSS/GitHub自动上传。
