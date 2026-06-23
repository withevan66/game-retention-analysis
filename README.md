# 移动游戏用户留存与 A/B Test 分析

## 项目概述

本项目基于 Cookie Cats 公开移动游戏 A/B 测试数据集，围绕移动游戏用户早期留存、版本效果差异和流失阶段定位进行分析。

原始数据包含约 9 万名用户的实验分组、游戏局数、次日留存和 7 日留存结果。由于原始数据不包含逐日行为日志、首次活跃日期和 3 日留存字段，本项目在保留原始数据的基础上，构造模拟逐日行为明细，用于补充 Cohort 留存、生命周期和流失阶段分析。

## 核心结论

- 共分析 90,189 名移动游戏用户，整体 D1 留存率为 44.52%，D7 留存率为 18.61%，7 日流失率为 81.39%。
- gate_40 版本 D7 留存率为 18.20%，低于 gate_30 版本的 19.02%，差值为 -0.82 个百分点。
- 两比例 Z 检验结果显示，gate_40 与 gate_30 的 D7 留存差异显著，p 值为 0.0016。
- 轻度玩家占比为 35.48%，但 D7 留存率仅为 1.93%，是早期流失治理的重点人群。
- 生命周期拆解显示，newbie_churn 用户占比为 51.15%，说明新手期体验和早期引导是优先优化方向。

## 分析目标

- 计算整体用户的 D1、D3、D7 留存表现
- 比较 gate_30 与 gate_40 两个版本的留存差异
- 使用两比例 Z 检验判断留存差异是否显著
- 基于游戏局数划分用户活跃层级
- 定位新手期、早期和中期流失用户
- 构建 Cohort 留存分析口径
- 输出结构化分析报告和可视化图表

## 数据说明

原始数据：

```text
data/cookie_cats.csv
```

扩写数据：

```text
data/game_user_profile_enriched.csv
data/game_daily_activity_simulated.csv
```

字段说明和指标口径：

```text
docs/data_dictionary.md
```

说明：D1 留存和 D7 留存来自原始公开数据；D3 留存、安装日期、首次活跃日期、Cohort 日期和逐日行为日志为基于原始字段构造的模拟扩写字段。

## 工具与方法

- Python / Pandas：数据清洗、指标计算、留存分析
- MySQL：指标口径复现与 SQL 查询练习
- Excel / Power BI：可视化看板制作
- A/B Test：实验组与对照组留存差异分析
- 显著性检验：两比例 Z 检验
- 用户分层：基于游戏局数划分轻度、中度、重度玩家
- Cohort 分析：基于模拟首次活跃日期构建留存矩阵

## 关键产出

分析 Notebook：

```text
notebooks/01_game_retention_analysis.ipynb
```

完整分析报告：

```text
reports/game_retention_report.md
```

可视化图表：

```text
dashboard/retention_curve_by_group.png
dashboard/retention_by_activity_segment.png
dashboard/user_share_by_lifecycle_stage.png
dashboard/cohort_retention_matrix.png
```

## 业务建议

- 优先优化新手期体验，重点检查首次进入游戏、前几局体验、关卡难度和引导流程。
- 针对轻度玩家设计早期激励，例如新手任务、登录奖励和低门槛活动。
- 谨慎放量 gate_40 版本，因为其 D7 留存表现显著低于 gate_30。
- 对中期流失用户做召回触达，例如活动提醒、阶段奖励和关卡目标提示。

