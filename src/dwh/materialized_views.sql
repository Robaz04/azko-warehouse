-- ═══════════════════════════════════════════════════════════════════════
-- AZKO DWH — Materialized Views (Pre-Aggregated OLAP Cubes)
-- Target: Neon.tech (PostgreSQL)
-- ═══════════════════════════════════════════════════════════════════════
--
-- Materialized Views menyimpan hasil agregasi ke disk.
-- Ini berfungsi seperti "pre-computed OLAP cube" untuk performa cepat.
-- Refresh setelah setiap ETL run.
-- ═══════════════════════════════════════════════════════════════════════


-- ═════════════════════════════════════════════════════════════════════
-- 1. MV: Monthly Sales Summary (Ringkasan Bulanan)
-- ═════════════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_monthly_sales AS
SELECT
    t.year,
    t.month,
    t.month_name,
    t.quarter,
    COUNT(DISTINCT f.transaction_id)                              AS total_transaksi,
    SUM(f.quantity_sold)                                          AS total_qty,
    SUM(f.final_sales)                                            AS total_revenue,
    SUM(f.gross_profit)                                           AS total_profit,
    SUM(f.cost_amount)                                            AS total_cost,
    SUM(f.discount_amount)                                        AS total_discount,
    ROUND(SUM(f.gross_profit) /
          NULLIF(SUM(f.final_sales), 0) * 100, 2)                AS margin_pct,
    ROUND(AVG(f.final_sales), 2)                                  AS avg_transaction
FROM fact_sales f
JOIN dim_time t ON f.time_key = t.time_key
GROUP BY t.year, t.month, t.month_name, t.quarter
ORDER BY t.year, t.month;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_monthly_year_month
    ON mv_monthly_sales(year, month);


-- ═════════════════════════════════════════════════════════════════════
-- 2. MV: Category × Region Cube (Cross-Analysis)
-- ═════════════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_category_region AS
SELECT
    p.category,
    s.region,
    t.year,
    t.quarter,
    SUM(f.quantity_sold)                                          AS total_qty,
    SUM(f.final_sales)                                            AS total_revenue,
    SUM(f.gross_profit)                                           AS total_profit,
    COUNT(DISTINCT f.transaction_id)                              AS total_trx
FROM fact_sales f
JOIN dim_product p ON f.product_key = p.product_key
JOIN dim_store s   ON f.store_key   = s.store_key
JOIN dim_time t    ON f.time_key    = t.time_key
GROUP BY p.category, s.region, t.year, t.quarter
ORDER BY p.category, s.region, t.year, t.quarter;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_cat_region
    ON mv_category_region(category, region, year, quarter);


-- ═════════════════════════════════════════════════════════════════════
-- 3. MV: Customer Segment Analysis
-- ═════════════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_customer_segment AS
SELECT
    c.membership_level,
    c.age_group,
    c.gender,
    t.year,
    t.quarter,
    COUNT(DISTINCT c.customer_key)                                AS unique_customers,
    COUNT(DISTINCT f.transaction_id)                              AS total_trx,
    SUM(f.final_sales)                                            AS total_revenue,
    ROUND(AVG(f.final_sales), 2)                                  AS avg_transaction,
    SUM(f.gross_profit)                                           AS total_profit
FROM fact_sales f
JOIN dim_customer c ON f.customer_key = c.customer_key
JOIN dim_time t     ON f.time_key     = t.time_key
GROUP BY c.membership_level, c.age_group, c.gender, t.year, t.quarter;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_cust_segment
    ON mv_customer_segment(membership_level, age_group, gender, year, quarter);


-- ═════════════════════════════════════════════════════════════════════
-- 4. MV: Store Performance
-- ═════════════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_store_performance AS
SELECT
    s.store_key,
    s.store_name,
    s.store_type,
    s.city,
    s.province,
    s.region,
    t.year,
    t.month,
    COUNT(DISTINCT f.transaction_id)                              AS total_trx,
    SUM(f.quantity_sold)                                          AS total_qty,
    SUM(f.final_sales)                                            AS total_revenue,
    SUM(f.gross_profit)                                           AS total_profit,
    ROUND(SUM(f.gross_profit) /
          NULLIF(SUM(f.final_sales), 0) * 100, 2)                AS margin_pct
FROM fact_sales f
JOIN dim_store s ON f.store_key = s.store_key
JOIN dim_time t  ON f.time_key  = t.time_key
GROUP BY s.store_key, s.store_name, s.store_type,
         s.city, s.province, s.region, t.year, t.month;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_store_perf
    ON mv_store_performance(store_key, year, month);


-- ═════════════════════════════════════════════════════════════════════
-- 5. MV: Promotion Effectiveness
-- ═════════════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_promotion_effectiveness AS
SELECT
    pr.campaign_id,
    pr.campaign_name,
    pr.campaign_type,
    pr.channel,
    pr.target_segment,
    COUNT(DISTINCT f.transaction_id)                              AS total_trx_with_promo,
    SUM(f.discount_amount)                                        AS total_discount_given,
    SUM(f.final_sales)                                            AS revenue_from_promo,
    SUM(f.gross_profit)                                           AS profit_from_promo,
    ROUND(SUM(f.final_sales) /
          NULLIF(SUM(f.discount_amount), 0), 2)                   AS roi_ratio
FROM fact_sales f
JOIN dim_promotion pr ON f.promotion_key = pr.promotion_key
WHERE pr.campaign_id != 'NO_PROMO'
GROUP BY pr.campaign_id, pr.campaign_name, pr.campaign_type,
         pr.channel, pr.target_segment;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_promo
    ON mv_promotion_effectiveness(campaign_id);


-- ═════════════════════════════════════════════════════════════════════
-- REFRESH COMMAND — Jalankan setelah setiap ETL
-- ═════════════════════════════════════════════════════════════════════

-- Refresh semua Materialized Views (jalankan setelah ETL selesai):
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_sales;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_category_region;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_customer_segment;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_store_performance;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_promotion_effectiveness;
