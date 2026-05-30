-- ═══════════════════════════════════════════════════════════════════════
-- AZKO DWH — OLAP Cube Operations (ROLLUP, CUBE, GROUPING SETS)
-- Target: Neon.tech (PostgreSQL)
-- ═══════════════════════════════════════════════════════════════════════
-- PostgreSQL mendukung OLAP natively via ROLLUP, CUBE, GROUPING SETS
-- Tidak perlu tool OLAP server terpisah — cukup SQL.
-- ═══════════════════════════════════════════════════════════════════════


-- ═════════════════════════════════════════════════════════════════════
-- 1. ROLLUP — Subtotal Hierarki (dari detail ke grand total)
-- ═════════════════════════════════════════════════════════════════════

-- 1A. ROLLUP: Year → Quarter → Month
-- Menghasilkan subtotal per bulan, per kuartal, per tahun, dan grand total
SELECT
    COALESCE(t.year::TEXT, '*** GRAND TOTAL ***')       AS year,
    COALESCE(t.quarter::TEXT, '** Year Subtotal **')    AS quarter,
    COALESCE(t.month_name, '* Quarter Subtotal *')      AS month_name,
    COUNT(DISTINCT f.transaction_id)                     AS total_transaksi,
    SUM(f.quantity_sold)                                 AS total_qty,
    SUM(f.final_sales)                                   AS total_revenue,
    SUM(f.gross_profit)                                  AS total_profit,
    ROUND(SUM(f.gross_profit) /
          NULLIF(SUM(f.final_sales), 0) * 100, 2)       AS margin_pct
FROM fact_sales f
JOIN dim_time t ON f.time_key = t.time_key
GROUP BY ROLLUP(t.year, t.quarter, t.month_name)
ORDER BY
    GROUPING(t.year), t.year,
    GROUPING(t.quarter), t.quarter,
    GROUPING(t.month_name), t.month_name;


-- 1B. ROLLUP: Region → Province → City → Store
-- Hierarki geografis dari region hingga toko individual
SELECT
    COALESCE(s.region, '*** GRAND TOTAL ***')            AS region,
    COALESCE(s.province, '** Region Subtotal **')        AS province,
    COALESCE(s.city, '* Province Subtotal *')            AS city,
    COALESCE(s.store_name, 'City Subtotal')              AS store_name,
    COUNT(DISTINCT f.transaction_id)                      AS total_transaksi,
    SUM(f.final_sales)                                    AS total_revenue,
    SUM(f.gross_profit)                                   AS total_profit
FROM fact_sales f
JOIN dim_store s ON f.store_key = s.store_key
GROUP BY ROLLUP(s.region, s.province, s.city, s.store_name)
ORDER BY
    GROUPING(s.region), s.region,
    GROUPING(s.province), s.province,
    GROUPING(s.city), s.city,
    GROUPING(s.store_name), s.store_name;


-- 1C. ROLLUP: Category → Brand → Product
-- Hierarki produk
SELECT
    COALESCE(p.category, '*** GRAND TOTAL ***')          AS category,
    COALESCE(p.brand, '** Category Subtotal **')         AS brand,
    COALESCE(p.product_name, '* Brand Subtotal *')       AS product_name,
    SUM(f.quantity_sold)                                  AS total_qty,
    SUM(f.final_sales)                                    AS total_revenue,
    SUM(f.gross_profit)                                   AS total_profit
FROM fact_sales f
JOIN dim_product p ON f.product_key = p.product_key
GROUP BY ROLLUP(p.category, p.brand, p.product_name)
ORDER BY
    GROUPING(p.category), p.category,
    GROUPING(p.brand), p.brand,
    GROUPING(p.product_name), total_revenue DESC;


-- ═════════════════════════════════════════════════════════════════════
-- 2. CUBE — Semua Kombinasi Agregasi
-- ═════════════════════════════════════════════════════════════════════

-- 2A. CUBE: Category × Region × Quarter
-- Menghasilkan SEMUA kemungkinan kombinasi subtotal (2^3 = 8 kombinasi)
SELECT
    COALESCE(p.category, '(All Categories)')             AS category,
    COALESCE(s.region, '(All Regions)')                  AS region,
    COALESCE(t.quarter::TEXT, '(All Quarters)')          AS quarter,
    COUNT(DISTINCT f.transaction_id)                      AS total_transaksi,
    SUM(f.quantity_sold)                                  AS total_qty,
    SUM(f.final_sales)                                    AS total_revenue,
    SUM(f.gross_profit)                                   AS total_profit,
    ROUND(AVG(f.final_sales), 2)                         AS avg_per_transaksi
FROM fact_sales f
JOIN dim_product p ON f.product_key = p.product_key
JOIN dim_store s   ON f.store_key   = s.store_key
JOIN dim_time t    ON f.time_key    = t.time_key
GROUP BY CUBE(p.category, s.region, t.quarter)
ORDER BY
    GROUPING(p.category), p.category,
    GROUPING(s.region), s.region,
    GROUPING(t.quarter), t.quarter;


-- 2B. CUBE: Membership × Payment Method
-- Cross-analysis pelanggan dan metode pembayaran
SELECT
    COALESCE(c.membership_level, '(All Membership)')     AS membership_level,
    COALESCE(pm.payment_method, '(All Payment)')         AS payment_method,
    COUNT(DISTINCT f.transaction_id)                      AS total_transaksi,
    SUM(f.final_sales)                                    AS total_revenue,
    ROUND(AVG(f.final_sales), 2)                         AS avg_transaction,
    SUM(f.gross_profit)                                   AS total_profit
FROM fact_sales f
JOIN dim_customer c       ON f.customer_key = c.customer_key
JOIN dim_payment_method pm ON f.payment_key = pm.payment_key
GROUP BY CUBE(c.membership_level, pm.payment_method)
ORDER BY
    GROUPING(c.membership_level), c.membership_level,
    GROUPING(pm.payment_method), pm.payment_method;


-- ═════════════════════════════════════════════════════════════════════
-- 3. GROUPING SETS — Kombinasi Custom (lebih fleksibel)
-- ═════════════════════════════════════════════════════════════════════

-- 3A. GROUPING SETS: Laporan Gabungan dalam 1 query
-- Menghasilkan: per category, per region, per quarter, dan grand total
SELECT
    CASE
        WHEN GROUPING(p.category) = 0 THEN 'By Category'
        WHEN GROUPING(s.region) = 0   THEN 'By Region'
        WHEN GROUPING(t.quarter) = 0  THEN 'By Quarter'
        ELSE 'Grand Total'
    END                                                   AS report_type,
    COALESCE(p.category, '')                              AS category,
    COALESCE(s.region, '')                                AS region,
    COALESCE(t.quarter::TEXT, '')                         AS quarter,
    COUNT(DISTINCT f.transaction_id)                      AS total_transaksi,
    SUM(f.final_sales)                                    AS total_revenue,
    SUM(f.gross_profit)                                   AS total_profit
FROM fact_sales f
JOIN dim_product p ON f.product_key = p.product_key
JOIN dim_store s   ON f.store_key   = s.store_key
JOIN dim_time t    ON f.time_key    = t.time_key
GROUP BY GROUPING SETS (
    (p.category),       -- subtotal per kategori
    (s.region),         -- subtotal per region
    (t.quarter),        -- subtotal per kuartal
    ()                  -- grand total
)
ORDER BY report_type, total_revenue DESC;


-- 3B. GROUPING SETS: Dashboard Summary (multi-dimensi)
SELECT
    CASE
        WHEN GROUPING(p.category) = 0 AND GROUPING(s.region) = 0 THEN 'Category × Region'
        WHEN GROUPING(p.category) = 0 AND GROUPING(t.quarter) = 0 THEN 'Category × Quarter'
        WHEN GROUPING(s.region) = 0 AND GROUPING(t.quarter) = 0 THEN 'Region × Quarter'
        ELSE 'Unknown'
    END                                                   AS analysis_type,
    COALESCE(p.category, '')                              AS category,
    COALESCE(s.region, '')                                AS region,
    COALESCE(t.quarter::TEXT, '')                         AS quarter,
    SUM(f.final_sales)                                    AS total_revenue,
    SUM(f.gross_profit)                                   AS total_profit
FROM fact_sales f
JOIN dim_product p ON f.product_key = p.product_key
JOIN dim_store s   ON f.store_key   = s.store_key
JOIN dim_time t    ON f.time_key    = t.time_key
GROUP BY GROUPING SETS (
    (p.category, s.region),     -- kategori × region
    (p.category, t.quarter),    -- kategori × kuartal
    (s.region, t.quarter)       -- region × kuartal
)
ORDER BY analysis_type, total_revenue DESC;
