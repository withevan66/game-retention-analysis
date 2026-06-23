-- 移动游戏用户留存与 A/B Test 分析
-- SQL 指标查询脚本
-- 说明：本脚本用于复现 Python Notebook 中的核心指标计算逻辑。
-- 数据表假设：
-- 1. game_user_profile_enriched：用户宽表
-- 2. game_daily_activity_simulated：模拟逐日行为明细表

/* =========================================================
   1. 整体用户规模与留存指标
   ========================================================= */

SELECT
    COUNT(DISTINCT user_id) AS total_users,
    AVG(CASE WHEN retention_1 = 'True' THEN 1 ELSE 0 END) AS d1_retention_rate,
    AVG(CASE WHEN retention_3 = 'True' THEN 1 ELSE 0 END) AS d3_retention_rate,
    AVG(CASE WHEN retention_7 = 'True' THEN 1 ELSE 0 END) AS d7_retention_rate,
    AVG(CASE WHEN is_churn_7d = 'True' THEN 1 ELSE 0 END) AS d7_churn_rate
FROM game_user_profile_enriched;


/* =========================================================
   2. 实验组与对照组留存对比
   ========================================================= */

SELECT
    experiment_group,
    COUNT(DISTINCT user_id) AS users,
    AVG(sum_gamerounds) AS avg_game_rounds,
    AVG(CASE WHEN retention_1 = 'True' THEN 1 ELSE 0 END) AS d1_retention_rate,
    AVG(CASE WHEN retention_3 = 'True' THEN 1 ELSE 0 END) AS d3_retention_rate,
    AVG(CASE WHEN retention_7 = 'True' THEN 1 ELSE 0 END) AS d7_retention_rate,
    AVG(CASE WHEN is_churn_7d = 'True' THEN 1 ELSE 0 END) AS d7_churn_rate
FROM game_user_profile_enriched
GROUP BY experiment_group
ORDER BY experiment_group;


/* =========================================================
   3. gate_40 相比 gate_30 的留存差值
   ========================================================= */

WITH group_metrics AS (
    SELECT
        experiment_group,
        AVG(CASE WHEN retention_1 = 'True' THEN 1 ELSE 0 END) AS d1_retention_rate,
        AVG(CASE WHEN retention_3 = 'True' THEN 1 ELSE 0 END) AS d3_retention_rate,
        AVG(CASE WHEN retention_7 = 'True' THEN 1 ELSE 0 END) AS d7_retention_rate
    FROM game_user_profile_enriched
    GROUP BY experiment_group
)
SELECT
    g40.d1_retention_rate - g30.d1_retention_rate AS d1_diff,
    g40.d3_retention_rate - g30.d3_retention_rate AS d3_diff,
    g40.d7_retention_rate - g30.d7_retention_rate AS d7_diff
FROM group_metrics g30
JOIN group_metrics g40
WHERE g30.experiment_group = 'gate_30'
  AND g40.experiment_group = 'gate_40';


/* =========================================================
   4. 按用户活跃层级拆解留存
   ========================================================= */

SELECT
    activity_segment,
    COUNT(DISTINCT user_id) AS users,
    COUNT(DISTINCT user_id) / (
        SELECT COUNT(DISTINCT user_id)
        FROM game_user_profile_enriched
    ) AS user_share,
    AVG(sum_gamerounds) AS avg_game_rounds,
    AVG(CASE WHEN retention_1 = 'True' THEN 1 ELSE 0 END) AS d1_retention_rate,
    AVG(CASE WHEN retention_3 = 'True' THEN 1 ELSE 0 END) AS d3_retention_rate,
    AVG(CASE WHEN retention_7 = 'True' THEN 1 ELSE 0 END) AS d7_retention_rate,
    AVG(CASE WHEN is_churn_7d = 'True' THEN 1 ELSE 0 END) AS d7_churn_rate
FROM game_user_profile_enriched
GROUP BY activity_segment
ORDER BY users DESC;


/* =========================================================
   5. 生命周期阶段与流失阶段定位
   ========================================================= */

SELECT
    lifecycle_stage,
    COUNT(DISTINCT user_id) AS users,
    COUNT(DISTINCT user_id) / (
        SELECT COUNT(DISTINCT user_id)
        FROM game_user_profile_enriched
    ) AS user_share,
    AVG(sum_gamerounds) AS avg_game_rounds,
    AVG(CASE WHEN retention_1 = 'True' THEN 1 ELSE 0 END) AS d1_retention_rate,
    AVG(CASE WHEN retention_3 = 'True' THEN 1 ELSE 0 END) AS d3_retention_rate,
    AVG(CASE WHEN retention_7 = 'True' THEN 1 ELSE 0 END) AS d7_retention_rate
FROM game_user_profile_enriched
GROUP BY lifecycle_stage
ORDER BY users DESC;


/* =========================================================
   6. Cohort 留存分析：按安装日期和 day_n 计算留存
   ========================================================= */

SELECT
    install_date,
    day_n,
    COUNT(DISTINCT user_id) AS users,
    SUM(CASE WHEN is_active = 'True' THEN 1 ELSE 0 END) AS active_users,
    SUM(CASE WHEN is_active = 'True' THEN 1 ELSE 0 END) / COUNT(DISTINCT user_id) AS retention_rate
FROM game_daily_activity_simulated
GROUP BY install_date, day_n
ORDER BY install_date, day_n;


/* =========================================================
   7. 实验组留存曲线
   ========================================================= */

SELECT
    experiment_group,
    day_n,
    COUNT(DISTINCT user_id) AS users,
    SUM(CASE WHEN is_active = 'True' THEN 1 ELSE 0 END) AS active_users,
    SUM(CASE WHEN is_active = 'True' THEN 1 ELSE 0 END) / COUNT(DISTINCT user_id) AS retention_rate
FROM game_daily_activity_simulated
GROUP BY experiment_group, day_n
ORDER BY experiment_group, day_n;


/* =========================================================
   8. 检查逐日游戏局数是否与用户总局数一致
   ========================================================= */

WITH daily_rounds AS (
    SELECT
        user_id,
        SUM(daily_game_rounds) AS total_daily_rounds
    FROM game_daily_activity_simulated
    GROUP BY user_id
)
SELECT
    COUNT(*) AS mismatch_users
FROM game_user_profile_enriched p
JOIN daily_rounds d
    ON p.user_id = d.user_id
WHERE p.sum_gamerounds <> d.total_daily_rounds;