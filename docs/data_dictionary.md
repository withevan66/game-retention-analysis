# 数据字典与指标口径说明

## 1. 数据来源

本项目使用 Cookie Cats 公开移动游戏 A/B 测试数据集作为原始数据。

原始数据文件：

```text
data/cookie_cats.csv

扩写后的数据文件包括：
data/game_user_profile_enriched.csv ：扩写后的用户宽表
data/game_daily_activity_simulated.csv：模拟逐日行为明细表


## 2. 原始数据字段说明

文件：data/cookie_cats.csv

字段名	含义	类型	说明
userid	用户 ID	int	用户唯一标识
version	实验版本	string	gate_30 表示在第 30 关设置关卡门槛，gate_40 表示在第 40 关设置关卡门槛
sum_gamerounds	游戏局数	int	用户在观察期内完成的游戏总局数
retention_1	次日留存	bool	用户是否在安装后第 1 天仍然活跃
retention_7	7 日留存	bool	用户是否在安装后第 7 天仍然活跃

## 3. 扩写用户宽表字段说明

文件：data/game_user_profile_enriched.csv

字段名	含义	类型	来源
user_id	用户 ID	int	由原始字段 userid 重命名
experiment_group	实验分组	string	由原始字段 version 重命名
sum_gamerounds	游戏总局数	int	原始字段
retention_1	次日留存	bool	原始字段
retention_3	3 日留存	bool	基于 retention_1、retention_7 和 sum_gamerounds 模拟生成
retention_7	7 日留存	bool	原始字段
install_date	安装日期	date	模拟生成
first_active_date	首次活跃日期	date	模拟生成，默认等于 install_date
cohort_date	Cohort 日期	date	基于 first_active_date 生成
cohort_week	Cohort 周	date	基于 first_active_date 所在周生成
is_new_user	是否新用户	bool	模拟生成
activity_segment	活跃层级	string	基于 sum_gamerounds 生成
lifecycle_stage	生命周期阶段	string	基于留存和游戏局数生成
is_churn_7d	是否 7 日流失	bool	基于 retention_7 生成

## 4. 模拟逐日行为明细字段说明

文件：data/game_daily_activity_simulated.csv

字段名	含义	类型	说明
user_id	用户 ID	int	用户唯一标识
experiment_group	实验分组	string	gate_30 或 gate_40
install_date	安装日期	date	用户模拟安装日期
active_date	活跃日期	date	用户安装后第 N 天对应的日期
day_n	安装后第几天	int	取值范围为 0 到 7
is_active	当天是否活跃	bool	是否在该日期活跃
daily_game_rounds	当天游戏局数	int	模拟分配的当天游戏局数
activity_segment	活跃层级	string	与用户宽表一致
retention_flag	留存标记	string	D0、D1、D3、D7 或空值

## 5. 指标口径说明

1.用户数 = 去重后的user_id数量

2.次日留存率 = retention_1 = True 的用户数/ 总用户数

3.3 日留存率 = retention_3 = True 的用户数 / 总用户数

4.7 日留存率 = retention_7 = True 的用户数 / 总用户数

5.7 日流失率 = retention_7 = False 的用户数 / 总用户数

6.gate_30：对照组
gate_40：实验组

业务含义：gate_30 表示游戏关卡门槛设置在第 30 关
gate_40 表示游戏关卡门槛设置在第 40 关

分析目标：比较 gate_30 和 gate_40 两组用户在游戏局数、D1 留存、D3 留存、D7 留存上的差异。

## 6. 用户分层原则

根据用户在观察期内的游戏总局数 sum_gamerounds，将用户划分为以下层级：
分层	规则	含义
not_started	sum_gamerounds = 0	未启动用户
light_player	1 <= sum_gamerounds <= 10	轻度玩家
medium_player	11 <= sum_gamerounds <= 50	中度玩家
heavy_player	sum_gamerounds >= 51	重度玩家

该分层用于分析不同活跃程度用户的留存和流失差异。

## 7. 生命周期阶段规则

根据游戏局数和留存情况，将用户划分为以下生命周期阶段：
阶段	规则	含义
not_started	sum_gamerounds = 0	用户没有真正开始游戏
newbie_churn	retention_1 = False	新手期即流失
early_churn	retention_1 = True 且 retention_3 = False	早期流失
mid_term_churn	retention_3 = True 且 retention_7 = False	中期流失
stable_active	retention_7 = True	7 日仍然活跃的稳定用户

该字段用于定位用户主要流失阶段。

#8. Cohort分析口径

cohort_date = first_active_date

cohort_week = first_active_date 所在周的周一日期