-- ═══════════════════════════════════════════════════════════════════════
-- AZKO DWH — 5 Operasi OLAP (Drill-Down, Roll-Up, Slice, Dice, Pivot)
-- Target: Neon.tech (PostgreSQL)
-- ═══════════════════════════════════════════════════════════════════════
--
-- Operasi OLAP memungkinkan analyst melihat data dari berbagai sudut
-- pandang dan level granularity secara interaktif.
-- ═══════════════════════════════════════════════════════════════════════


-- ═════════════════════════════════════════════════════════════════════
-- 1. DRILL-DOWN — Melihat data dari level umum ke detail
--    (Zoom in: Year → Quarter → Month → Day)
-- ═════════════════════════════════════════════════════════════════════

-- Level 1: Per Year (paling umum)
SELECT
    t.year,
    SUM(f.final_sales)     AS total_revenue,
    SUM(f.gross_profit)    AS total_profit,
    SUM(f.quantity_sold)   AS total_qty
FROM fact_sales f
JOIN dim_time t ON f.time_key = t.time_key
GROUP BY t.year
ORDER BY t.year;

-- Level 2: Drill-down ke Quarter (dalam tahun 2025)
SELECT
    t.year, t.quarter,
    SUM(f.final_sales)     AS total_revenue,
    SUM(f.gross_profit)    AS total_profit,
    SUM(f.quantity_sold)   AS total_qty
FROM fact_sales f
JOIN dim_time t ON f.time_key = t.time_key
WHERE t.year = 2025
GROUP BY t.year, t.quarter
ORDER BY t.quarter;

-- Level 3: Drill-down ke Month (dalam Q1 2025)
SELECT
    t.year, t.quarter, t.month, t.month_name,
    SUM(f.final_sales)     AS total_revenue,
    SUM(f.gross_profit)    AS total_profit,
    SUM(f.quantity_sold)   AS total_qty
FROM fact_sales f
JOIN dim_time t ON f.time_key = t.time_key
WHERE t.year = 2025 AND t.quarter = 1
GROUP BY t.year, t.quarter, t.month, t.month_name
ORDER BY t.month;

-- Level 4: Drill-down ke Day (dalam Januari 2025)
SELECT
    t.full_date, t.day_name,
    SUM(f.final_sales)     AS total_revenue,
    SUM(f.gross_profit)    AS total_profit,
    SUM(f.quantity_sold)   AS total_qty
FROM fact_sales f
JOIN dim_time t ON f.time_key = t.time_key
WHERE t.year = 2025 AND t.month = 1
GROUP BY t.full_date, t.day_name
ORDER BY t.full_date;

-- Drill-down Geografis: Region → Province → City → Store
-- Level 1: Per Region
SELECT s.region, SUM(f.final_sales) AS revenue
FROM fact_sales f
JOIN dim_store s ON f.store_key = s.store_key
GROUP BY s.region ORDER BY revenue DESC;

-- Level 2: Drill-down ke Province (Region Barat)
SELECT s.region, s.province, SUM(f.final_sales) AS revenue
FROM fact_sales f
JOIN dim_store s ON f.store_key = s.store_key
WHERE s.region = 'Barat'
GROUP BY s.region, s.province ORDER BY revenue DESC;

-- Level 3: Drill-down ke City (Jawa Barat)
SELECT s.province, s.city, SUM(f.final_sales) AS revenue
FROM fact_sales f
JOIN dim_store s ON f.store_key = s.store_key
WHERE s.province = 'Jawa Barat'
GROUP BY s.province, s.city ORDER BY revenue DESC;

-- Level 4: Drill-down ke Store (Kota Bandung)
SELECT s.city, s.store_name, SUM(f.final_sales) AS revenue
FROM fact_sales f
JOIN dim_store s ON f.store_key = s.store_key
WHERE s.city = 'Bandung'
GROUP BY s.city, s.store_name ORDER BY revenue DESC;


-- ═════════════════════════════════════════════════════════════════════
-- 2. ROLL-UP — Kebalikan drill-down: detail ke umum
--    (Zoom out: Store → City → Province → Region → Grand Total)
-- ═════════════════════════════════════════════════════════════════════

-- Roll-Up: Dari store detail → grand total menggunakan SQL ROLLUP
SELECT
    COALESCE(s.region, '>> GRAND TOTAL')                 AS region,
    COALESCE(s.province, '>> Region Total')              AS province,
    COALESCE(s.city, '>> Province Total')                AS city,
    SUM(f.final_sales)                                    AS total_revenue,
    SUM(f.gross_profit)                                   AS total_profit,
    COUNT(DISTINCT f.transaction_id)                      AS total_trx
FROM fact_sales f
JOIN dim_store s ON f.store_key = s.store_key
GROUP BY ROLLUP(s.region, s.province, s.city)
ORDER BY
    GROUPING(s.region), s.region,
    GROUPING(s.province), s.province,
    GROUPING(s.city), s.city;

-- Roll-Up Produk: Product → Brand → Category → Grand Total
SELECT
    COALESCE(p.category, '>> GRAND TOTAL')               AS category,
    COALESCE(p.brand, '>> Category Total')               AS brand,
    SUM(f.quantity_sold)                                   AS total_qty,
    SUM(f.final_sales)                                    AS total_revenue,
    SUM(f.gross_profit)                                   AS total_profit
FROM fact_sales f
JOIN dim_product p ON f.product_key = p.product_key
GROUP BY ROLLUP(p.category, p.brand)
ORDER BY
    GROUPING(p.category), p.category,
    GROUPING(p.brand), p.brand;


-- ═════════════════════════════════════════════════════════════════════
-- 3. SLICE — Memotong cube pada 1 dimensi (memilih 1 nilai)
--    Seperti mengambil 1 "irisan" dari kubus multidimensi
-- ═════════════════════════════════════════════════════════════════════

-- Slice by Time: Hanya Q1 2025
SELECT
    p.category,
    s.region,
    SUM(f.final_sales)    AS total_revenue,
    SUM(f.gross_profit)   AS total_profit,
    SUM(f.quantity_sold)  AS total_qty
FROM fact_sales f
JOIN dim_time t    ON f.time_key    = t.time_key
JOIN dim_product p ON f.product_key = p.product_key
JOIN dim_store s   ON f.store_key   = s.store_key
WHERE t.quarter = 1 AND t.year = 2025          -- ← SLICE pada Q1 2025
GROUP BY p.category, s.region
ORDER BY total_revenue DESC;

-- Slice by Product Category: Hanya "Kitchenware"
SELECT
    t.month_name,
    s.region,
    c.membership_level,
    SUM(f.final_sales)    AS total_revenue,
    SUM(f.quantity_sold)  AS total_qty
FROM fact_sales f
JOIN dim_time t      ON f.time_key      = t.time_key
JOIN dim_product p   ON f.product_key   = p.product_key
JOIN dim_store s     ON f.store_key     = s.store_key
JOIN dim_customer c  ON f.customer_key  = c.customer_key
WHERE p.category = 'Kitchenware'               -- ← SLICE pada Kitchenware
GROUP BY t.month_name, t.month, s.region, c.membership_level
ORDER BY t.month, total_revenue DESC;

-- Slice by Store Region: Hanya "Barat"
SELECT
    t.quarter,
    p.category,
    SUM(f.final_sales)    AS total_revenue,
    SUM(f.gross_profit)   AS total_profit
FROM fact_sales f
JOIN dim_time t    ON f.time_key    = t.time_key
JOIN dim_product p ON f.product_key = p.product_key
JOIN dim_store s   ON f.store_key   = s.store_key
WHERE s.region = 'Barat'                        -- ← SLICE pada region Barat
GROUP BY t.quarter, p.category
ORDER BY t.quarter, total_revenue DESC;

-- Slice by Membership: Hanya "Platinum"
SELECT
    t.month_name,
    p.category,
    pm.payment_method,
    SUM(f.final_sales)    AS total_revenue,
    SUM(f.quantity_sold)  AS total_qty
FROM fact_sales f
JOIN dim_time t             ON f.time_key      = t.time_key
JOIN dim_product p          ON f.product_key   = p.product_key
JOIN dim_customer c         ON f.customer_key  = c.customer_key
JOIN dim_payment_method pm  ON f.payment_key   = pm.payment_key
WHERE c.membership_level = 'Platinum'           -- ← SLICE pada Platinum
GROUP BY t.month_name, t.month, p.category, pm.payment_method
ORDER BY t.month, total_revenue DESC;


-- ═════════════════════════════════════════════════════════════════════
-- 4. DICE — Memotong cube pada MULTIPLE dimensi (filter kombinasi)
--    Seperti mengambil "sub-kubus" kecil dari kubus besar
-- ═════════════════════════════════════════════════════════════════════

-- Dice: Kitchenware + Furniture, di Region Barat, Q1-Q2 2025
SELECT
    t.quarter,
    p.category,
    s.city,
    SUM(f.final_sales)    AS total_revenue,
    SUM(f.quantity_sold)  AS total_qty,
    SUM(f.gross_profit)   AS total_profit
FROM fact_sales f
JOIN dim_time t    ON f.time_key    = t.time_key
JOIN dim_product p ON f.product_key = p.product_key
JOIN dim_store s   ON f.store_key   = s.store_key
WHERE p.category IN ('Kitchenware', 'Furniture')   -- ← DICE: 2 kategori
  AND s.region = 'Barat'                            -- ← DICE: 1 region
  AND t.quarter IN (1, 2)                           -- ← DICE: 2 kuartal
GROUP BY t.quarter, p.category, s.city
ORDER BY t.quarter, p.category, total_revenue DESC;

-- Dice: Gold + Platinum customers, menggunakan E-Wallet + Credit Card
SELECT
    c.membership_level,
    pm.payment_method,
    p.category,
    SUM(f.final_sales)                    AS total_revenue,
    COUNT(DISTINCT f.transaction_id)      AS total_trx,
    ROUND(AVG(f.final_sales), 2)          AS avg_transaction
FROM fact_sales f
JOIN dim_customer c         ON f.customer_key  = c.customer_key
JOIN dim_payment_method pm  ON f.payment_key   = pm.payment_key
JOIN dim_product p          ON f.product_key   = p.product_key
WHERE c.membership_level IN ('Gold', 'Platinum')           -- ← DICE
  AND pm.payment_method IN ('E-Wallet', 'Credit Card')     -- ← DICE
GROUP BY c.membership_level, pm.payment_method, p.category
ORDER BY c.membership_level, total_revenue DESC;

-- Dice: Weekend sales, di kota besar (Jakarta, Surabaya, Bandung)
SELECT
    t.day_name,
    s.city,
    p.category,
    SUM(f.final_sales)     AS total_revenue,
    SUM(f.quantity_sold)   AS total_qty
FROM fact_sales f
JOIN dim_time t    ON f.time_key    = t.time_key
JOIN dim_store s   ON f.store_key   = s.store_key
JOIN dim_product p ON f.product_key = p.product_key
WHERE t.is_weekend = TRUE                                  -- ← DICE
  AND s.city IN ('Jakarta', 'Surabaya', 'Bandung')         -- ← DICE
GROUP BY t.day_name, t.day_of_week, s.city, p.category
ORDER BY t.day_of_week, s.city, total_revenue DESC;


-- ═════════════════════════════════════════════════════════════════════
-- 5. PIVOT — Merotasi baris menjadi kolom (Crosstab)
--    PostgreSQL menggunakan CASE WHEN atau crosstab()
-- ═════════════════════════════════════════════════════════════════════

-- 5A. Pivot: Revenue per Category × Quarter (baris=kategori, kolom=kuartal)
SELECT
    p.category,
    SUM(CASE WHEN t.quarter = 1 THEN f.final_sales ELSE 0 END) AS "Q1",
    SUM(CASE WHEN t.quarter = 2 THEN f.final_sales ELSE 0 END) AS "Q2",
    SUM(CASE WHEN t.quarter = 3 THEN f.final_sales ELSE 0 END) AS "Q3",
    SUM(CASE WHEN t.quarter = 4 THEN f.final_sales ELSE 0 END) AS "Q4",
    SUM(f.final_sales)                                          AS "Total"
FROM fact_sales f
JOIN dim_time t    ON f.time_key    = t.time_key
JOIN dim_product p ON f.product_key = p.product_key
WHERE t.year = 2025
GROUP BY p.category
ORDER BY "Total" DESC;

-- 5B. Pivot: Revenue per Region × Payment Method
SELECT
    s.region,
    SUM(CASE WHEN pm.payment_method = 'Cash'          THEN f.final_sales ELSE 0 END) AS "Cash",
    SUM(CASE WHEN pm.payment_method = 'Debit Card'    THEN f.final_sales ELSE 0 END) AS "Debit Card",
    SUM(CASE WHEN pm.payment_method = 'Credit Card'   THEN f.final_sales ELSE 0 END) AS "Credit Card",
    SUM(CASE WHEN pm.payment_method = 'E-Wallet'      THEN f.final_sales ELSE 0 END) AS "E-Wallet",
    SUM(CASE WHEN pm.payment_method = 'Bank Transfer'  THEN f.final_sales ELSE 0 END) AS "Bank Transfer",
    SUM(f.final_sales)                                                                 AS "Total"
FROM fact_sales f
JOIN dim_store s            ON f.store_key   = s.store_key
JOIN dim_payment_method pm  ON f.payment_key = pm.payment_key
GROUP BY s.region
ORDER BY "Total" DESC;

-- 5C. Pivot: Quantity per Membership × Category
SELECT
    c.membership_level,
    SUM(CASE WHEN p.category = 'Kitchenware'     THEN f.quantity_sold ELSE 0 END) AS "Kitchenware",
    SUM(CASE WHEN p.category = 'Home Decor'      THEN f.quantity_sold ELSE 0 END) AS "Home Decor",
    SUM(CASE WHEN p.category = 'Cleaning Tools'  THEN f.quantity_sold ELSE 0 END) AS "Cleaning Tools",
    SUM(CASE WHEN p.category = 'Furniture'       THEN f.quantity_sold ELSE 0 END) AS "Furniture",
    SUM(CASE WHEN p.category = 'Bathroom'        THEN f.quantity_sold ELSE 0 END) AS "Bathroom",
    SUM(CASE WHEN p.category = 'Electrical'      THEN f.quantity_sold ELSE 0 END) AS "Electrical",
    SUM(CASE WHEN p.category = 'Storage'         THEN f.quantity_sold ELSE 0 END) AS "Storage",
    SUM(f.quantity_sold)                                                            AS "Total"
FROM fact_sales f
JOIN dim_customer c ON f.customer_key = c.customer_key
JOIN dim_product p  ON f.product_key  = p.product_key
GROUP BY c.membership_level
ORDER BY "Total" DESC;

-- 5D. Pivot: Monthly Profit per Region (baris=bulan, kolom=region)
SELECT
    t.month_name,
    SUM(CASE WHEN s.region = 'Barat'  THEN f.gross_profit ELSE 0 END) AS "Barat",
    SUM(CASE WHEN s.region = 'Tengah' THEN f.gross_profit ELSE 0 END) AS "Tengah",
    SUM(CASE WHEN s.region = 'Timur'  THEN f.gross_profit ELSE 0 END) AS "Timur",
    SUM(f.gross_profit)                                                 AS "Total"
FROM fact_sales f
JOIN dim_time t  ON f.time_key  = t.time_key
JOIN dim_store s ON f.store_key = s.store_key
WHERE t.year = 2025
GROUP BY t.month_name, t.month
ORDER BY t.month;

-- 5E. Pivot: Age Group × Gender (jumlah transaksi)
SELECT
    c.age_group,
    COUNT(DISTINCT CASE WHEN c.gender = 'Male'   THEN f.transaction_id END) AS "Male",
    COUNT(DISTINCT CASE WHEN c.gender = 'Female' THEN f.transaction_id END) AS "Female",
    COUNT(DISTINCT f.transaction_id)                                         AS "Total"
FROM fact_sales f
JOIN dim_customer c ON f.customer_key = c.customer_key
GROUP BY c.age_group
ORDER BY "Total" DESC;
