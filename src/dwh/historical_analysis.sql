-- ═══════════════════════════════════════════════════════════════════════
-- AZKO DWH — Analisis Data Historis (Historical / Trend Analysis)
-- Target: Neon.tech (PostgreSQL)
-- ═══════════════════════════════════════════════════════════════════════
--
-- Analisis historis melihat pola, tren, dan perubahan data
-- dari waktu ke waktu — ini adalah kekuatan utama Data Warehouse.
-- ═══════════════════════════════════════════════════════════════════════


-- ═════════════════════════════════════════════════════════════════════
-- 1. TREND ANALYSIS — Tren Penjualan dari Waktu ke Waktu
-- ═════════════════════════════════════════════════════════════════════

-- 1A. Tren Revenue Bulanan + Moving Average 3 Bulan
SELECT
    t.year,
    t.month,
    t.month_name,
    SUM(f.final_sales)                                          AS monthly_revenue,
    ROUND(AVG(SUM(f.final_sales)) OVER (
        ORDER BY t.year, t.month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                                       AS moving_avg_3m,
    SUM(f.gross_profit)                                         AS monthly_profit,
    ROUND(AVG(SUM(f.gross_profit)) OVER (
        ORDER BY t.year, t.month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                                       AS profit_moving_avg_3m
FROM fact_sales f
JOIN dim_time t ON f.time_key = t.time_key
GROUP BY t.year, t.month, t.month_name
ORDER BY t.year, t.month;


-- 1B. Tren Revenue Mingguan
SELECT
    t.year,
    t.week_of_year,
    MIN(t.full_date)                                             AS week_start,
    SUM(f.final_sales)                                           AS weekly_revenue,
    SUM(f.quantity_sold)                                          AS weekly_qty,
    COUNT(DISTINCT f.transaction_id)                              AS weekly_trx
FROM fact_sales f
JOIN dim_time t ON f.time_key = t.time_key
GROUP BY t.year, t.week_of_year
ORDER BY t.year, t.week_of_year;


-- ═════════════════════════════════════════════════════════════════════
-- 2. GROWTH ANALYSIS — Month-over-Month (MoM) Growth
-- ═════════════════════════════════════════════════════════════════════

-- 2A. Month-over-Month Revenue Growth
SELECT
    t.year,
    t.month,
    t.month_name,
    SUM(f.final_sales)                                           AS current_revenue,
    LAG(SUM(f.final_sales)) OVER (ORDER BY t.year, t.month)      AS prev_month_revenue,
    ROUND(
        (SUM(f.final_sales) - LAG(SUM(f.final_sales)) OVER (ORDER BY t.year, t.month))
        / NULLIF(LAG(SUM(f.final_sales)) OVER (ORDER BY t.year, t.month), 0)
        * 100, 2
    )                                                             AS mom_growth_pct
FROM fact_sales f
JOIN dim_time t ON f.time_key = t.time_key
GROUP BY t.year, t.month, t.month_name
ORDER BY t.year, t.month;


-- 2B. Quarter-over-Quarter Growth
SELECT
    t.year,
    t.quarter,
    SUM(f.final_sales)                                           AS current_revenue,
    LAG(SUM(f.final_sales)) OVER (ORDER BY t.year, t.quarter)    AS prev_quarter_revenue,
    ROUND(
        (SUM(f.final_sales) - LAG(SUM(f.final_sales)) OVER (ORDER BY t.year, t.quarter))
        / NULLIF(LAG(SUM(f.final_sales)) OVER (ORDER BY t.year, t.quarter), 0)
        * 100, 2
    )                                                             AS qoq_growth_pct,
    SUM(f.gross_profit)                                           AS current_profit,
    LAG(SUM(f.gross_profit)) OVER (ORDER BY t.year, t.quarter)    AS prev_quarter_profit
FROM fact_sales f
JOIN dim_time t ON f.time_key = t.time_key
GROUP BY t.year, t.quarter
ORDER BY t.year, t.quarter;


-- ═════════════════════════════════════════════════════════════════════
-- 3. CUMULATIVE ANALYSIS — Running Total / YTD
-- ═════════════════════════════════════════════════════════════════════

-- 3A. Year-to-Date (YTD) Revenue
SELECT
    t.year,
    t.month,
    t.month_name,
    SUM(f.final_sales)                                           AS monthly_revenue,
    SUM(SUM(f.final_sales)) OVER (
        PARTITION BY t.year
        ORDER BY t.month
    )                                                             AS ytd_revenue,
    SUM(f.gross_profit)                                           AS monthly_profit,
    SUM(SUM(f.gross_profit)) OVER (
        PARTITION BY t.year
        ORDER BY t.month
    )                                                             AS ytd_profit
FROM fact_sales f
JOIN dim_time t ON f.time_key = t.time_key
GROUP BY t.year, t.month, t.month_name
ORDER BY t.year, t.month;


-- 3B. Cumulative Transaction Count
SELECT
    t.year,
    t.month,
    t.month_name,
    COUNT(DISTINCT f.transaction_id)                              AS monthly_trx,
    SUM(COUNT(DISTINCT f.transaction_id)) OVER (
        PARTITION BY t.year
        ORDER BY t.month
    )                                                             AS ytd_trx,
    SUM(f.quantity_sold)                                          AS monthly_qty,
    SUM(SUM(f.quantity_sold)) OVER (
        PARTITION BY t.year
        ORDER BY t.month
    )                                                             AS ytd_qty
FROM fact_sales f
JOIN dim_time t ON f.time_key = t.time_key
GROUP BY t.year, t.month, t.month_name
ORDER BY t.year, t.month;


-- ═════════════════════════════════════════════════════════════════════
-- 4. RANKING & COMPARATIVE — Perbandingan Historis
-- ═════════════════════════════════════════════════════════════════════

-- 4A. Ranking Produk per Kuartal (siapa yang naik/turun?)
SELECT
    t.year,
    t.quarter,
    p.product_name,
    p.category,
    SUM(f.final_sales)                                           AS revenue,
    RANK() OVER (
        PARTITION BY t.year, t.quarter
        ORDER BY SUM(f.final_sales) DESC
    )                                                             AS rank_in_quarter,
    LAG(RANK() OVER (
        PARTITION BY t.year, t.quarter
        ORDER BY SUM(f.final_sales) DESC
    )) OVER (
        PARTITION BY p.product_name
        ORDER BY t.year, t.quarter
    )                                                             AS prev_quarter_rank
FROM fact_sales f
JOIN dim_time t    ON f.time_key    = t.time_key
JOIN dim_product p ON f.product_key = p.product_key
GROUP BY t.year, t.quarter, p.product_name, p.category
ORDER BY t.year, t.quarter, revenue DESC;


-- 4B. Ranking Store per Bulan
SELECT
    t.year,
    t.month,
    t.month_name,
    s.store_name,
    s.city,
    SUM(f.final_sales)                                           AS revenue,
    RANK() OVER (
        PARTITION BY t.year, t.month
        ORDER BY SUM(f.final_sales) DESC
    )                                                             AS monthly_rank
FROM fact_sales f
JOIN dim_time t  ON f.time_key  = t.time_key
JOIN dim_store s ON f.store_key = s.store_key
GROUP BY t.year, t.month, t.month_name, s.store_name, s.city
ORDER BY t.year, t.month, revenue DESC;


-- 4C. Contribution Percentage per Category per Month
SELECT
    t.year,
    t.month,
    t.month_name,
    p.category,
    SUM(f.final_sales)                                           AS category_revenue,
    SUM(SUM(f.final_sales)) OVER (
        PARTITION BY t.year, t.month
    )                                                             AS total_month_revenue,
    ROUND(
        100.0 * SUM(f.final_sales) /
        NULLIF(SUM(SUM(f.final_sales)) OVER (PARTITION BY t.year, t.month), 0)
    , 2)                                                          AS pct_contribution
FROM fact_sales f
JOIN dim_time t    ON f.time_key    = t.time_key
JOIN dim_product p ON f.product_key = p.product_key
GROUP BY t.year, t.month, t.month_name, p.category
ORDER BY t.year, t.month, pct_contribution DESC;


-- ═════════════════════════════════════════════════════════════════════
-- 5. SEASONALITY & PATTERN — Pola Musiman
-- ═════════════════════════════════════════════════════════════════════

-- 5A. Pola Penjualan per Hari dalam Seminggu
SELECT
    t.day_name,
    t.day_of_week,
    COUNT(DISTINCT f.transaction_id)                              AS avg_daily_trx,
    ROUND(AVG(f.final_sales), 2)                                  AS avg_transaction_value,
    SUM(f.final_sales)                                            AS total_revenue,
    SUM(f.quantity_sold)                                           AS total_qty
FROM fact_sales f
JOIN dim_time t ON f.time_key = t.time_key
GROUP BY t.day_name, t.day_of_week
ORDER BY t.day_of_week;


-- 5B. Weekend vs Weekday Performance
SELECT
    CASE WHEN t.is_weekend THEN 'Weekend' ELSE 'Weekday' END    AS day_type,
    COUNT(DISTINCT t.full_date)                                   AS total_days,
    COUNT(DISTINCT f.transaction_id)                              AS total_trx,
    ROUND(COUNT(DISTINCT f.transaction_id)::NUMERIC /
          NULLIF(COUNT(DISTINCT t.full_date), 0), 2)              AS avg_trx_per_day,
    SUM(f.final_sales)                                            AS total_revenue,
    ROUND(SUM(f.final_sales) /
          NULLIF(COUNT(DISTINCT t.full_date), 0), 2)              AS avg_revenue_per_day
FROM fact_sales f
JOIN dim_time t ON f.time_key = t.time_key
GROUP BY CASE WHEN t.is_weekend THEN 'Weekend' ELSE 'Weekday' END;


-- 5C. Monthly Seasonality Index
-- Membandingkan setiap bulan dengan rata-rata bulanan
SELECT
    t.month,
    t.month_name,
    SUM(f.final_sales)                                            AS monthly_revenue,
    ROUND(AVG(SUM(f.final_sales)) OVER (), 2)                    AS avg_monthly,
    ROUND(
        SUM(f.final_sales) / NULLIF(AVG(SUM(f.final_sales)) OVER (), 0)
    , 4)                                                          AS seasonality_index
    -- > 1.0 = bulan di atas rata-rata, < 1.0 = bulan di bawah rata-rata
FROM fact_sales f
JOIN dim_time t ON f.time_key = t.time_key
WHERE t.year = 2025
GROUP BY t.month, t.month_name
ORDER BY t.month;


-- ═════════════════════════════════════════════════════════════════════
-- 6. MARGIN & PROFITABILITY TREND
-- ═════════════════════════════════════════════════════════════════════

-- 6A. Profit Margin Trend per Bulan
SELECT
    t.year,
    t.month,
    t.month_name,
    SUM(f.final_sales)                                           AS revenue,
    SUM(f.cost_amount)                                           AS total_cost,
    SUM(f.gross_profit)                                          AS gross_profit,
    ROUND(SUM(f.gross_profit) /
          NULLIF(SUM(f.final_sales), 0) * 100, 2)               AS gross_margin_pct,
    ROUND(AVG(SUM(f.gross_profit) /
          NULLIF(SUM(f.final_sales), 0) * 100) OVER (
        ORDER BY t.year, t.month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                                         AS margin_moving_avg_3m
FROM fact_sales f
JOIN dim_time t ON f.time_key = t.time_key
GROUP BY t.year, t.month, t.month_name
ORDER BY t.year, t.month;


-- 6B. Category Profitability Over Time
SELECT
    t.quarter,
    p.category,
    SUM(f.final_sales)                                           AS revenue,
    SUM(f.gross_profit)                                          AS profit,
    ROUND(SUM(f.gross_profit) /
          NULLIF(SUM(f.final_sales), 0) * 100, 2)               AS margin_pct,
    SUM(f.quantity_sold)                                          AS qty_sold
FROM fact_sales f
JOIN dim_time t    ON f.time_key    = t.time_key
JOIN dim_product p ON f.product_key = p.product_key
WHERE t.year = 2025
GROUP BY t.quarter, p.category
ORDER BY t.quarter, margin_pct DESC;
