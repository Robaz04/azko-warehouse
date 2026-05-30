# 🔍 Audit Data Warehouse AZKO — Gap Analysis & Penambahan

## Status Sebelum vs Sesudah

| Komponen DWH | Sebelum | Sesudah | Status |
|---|---|---|---|
| **1. Design (Star Schema)** | ✅ 7 dimensi + 1 fact table | ✅ Tidak berubah | Sudah lengkap |
| **2. ETL (Extract-Transform-Load)** | ✅ Full pipeline MySQL → PostgreSQL | ✅ + MV refresh | Sudah lengkap |
| **3. Dimension Tables** | ✅ 7 dimensi + SCD Type 2 (dim_promotion) | ✅ Tidak berubah | Sudah lengkap |
| **4. Cube / OLAP** | ❌ Belum ada | ✅ ROLLUP + CUBE + GROUPING SETS + 5 Operasi OLAP | **BARU** |
| **5. Historical Analysis** | ❌ Hanya GROUP BY dasar | ✅ MoM, YTD, Moving Avg, Seasonality, Ranking | **BARU** |
| **6. Materialized Views** | ❌ Belum ada | ✅ 5 pre-aggregated views + auto-refresh | **BARU** |

---

## File yang Ditambahkan

| # | File | Isi |
|---|---|---|
| 1 | [olap_cube_queries.sql](file:///d:/KULIAH/SEMESTER%206/Data%20Warehouse/azko-warehouse/src/dwh/olap_cube_queries.sql) | ROLLUP, CUBE, GROUPING SETS (SQL:1999 OLAP) |
| 2 | [olap_operations.sql](file:///d:/KULIAH/SEMESTER%206/Data%20Warehouse/azko-warehouse/src/dwh/olap_operations.sql) | 5 operasi OLAP: Drill-Down, Roll-Up, Slice, Dice, Pivot |
| 3 | [historical_analysis.sql](file:///d:/KULIAH/SEMESTER%206/Data%20Warehouse/azko-warehouse/src/dwh/historical_analysis.sql) | Trend, MoM/QoQ growth, YTD, Moving Avg, Seasonality |
| 4 | [materialized_views.sql](file:///d:/KULIAH/SEMESTER%206/Data%20Warehouse/azko-warehouse/src/dwh/materialized_views.sql) | 5 Materialized Views (pre-aggregated OLAP cubes) |

## File yang Diupdate

| # | File | Perubahan |
|---|---|---|
| 1 | [etl_pipeline.py](file:///d:/KULIAH/SEMESTER%206/Data%20Warehouse/azko-warehouse/src/etl_pipeline.py) | + `refresh_materialized_views()` — auto-refresh MV setelah ETL |

---

## 📐 Detail Komponen yang Ditambahkan

### 4. OLAP Cube (ROLLUP, CUBE, GROUPING SETS)

PostgreSQL mendukung OLAP cube **natively** tanpa perlu OLAP server terpisah.

| Operasi SQL | Fungsi | Contoh di AZKO |
|---|---|---|
| `ROLLUP(a, b, c)` | Subtotal hierarkis (a → a,b → a,b,c → grand total) | Year → Quarter → Month |
| `CUBE(a, b, c)` | Semua 2ⁿ kombinasi subtotal | Category × Region × Quarter |
| `GROUPING SETS(...)` | Kombinasi custom yang kita pilih sendiri | Per-category + per-region + grand total dalam 1 query |

**File:** [olap_cube_queries.sql](file:///d:/KULIAH/SEMESTER%206/Data%20Warehouse/azko-warehouse/src/dwh/olap_cube_queries.sql)

---

### 5. Lima Operasi OLAP

| # | Operasi | Penjelasan | Contoh di AZKO |
|---|---|---|---|
| 1 | **Drill-Down** | Zoom in: umum → detail | Year → Q → Month → Day |
| 2 | **Roll-Up** | Zoom out: detail → umum | Store → City → Province → Region |
| 3 | **Slice** | Filter 1 dimensi (1 "irisan") | Hanya Q1 2025, hanya Kitchenware |
| 4 | **Dice** | Filter multi dimensi (sub-kubus) | Kitchenware+Furniture, Region Barat, Q1-Q2 |
| 5 | **Pivot** | Rotasi baris ↔ kolom (crosstab) | Category × Quarter revenue matrix |

**File:** [olap_operations.sql](file:///d:/KULIAH/SEMESTER%206/Data%20Warehouse/azko-warehouse/src/dwh/olap_operations.sql)

---

### 6. Analisis Data Historis

| # | Analisis | Teknik SQL | Penjelasan |
|---|---|---|---|
| 1 | Trend Analysis | `AVG() OVER (ROWS BETWEEN...)` | Moving Average 3 bulan |
| 2 | Growth Analysis | `LAG() OVER (ORDER BY...)` | Month-over-Month & QoQ growth % |
| 3 | Cumulative / YTD | `SUM() OVER (PARTITION BY year ORDER BY month)` | Year-to-Date running total |
| 4 | Ranking | `RANK() OVER (PARTITION BY...)` | Top produk per kuartal |
| 5 | Seasonality | Index bulan vs rata-rata | Bulan mana yang di atas/bawah normal |
| 6 | Profitability | Margin trend + moving avg | Tren profit margin bulanan |

**File:** [historical_analysis.sql](file:///d:/KULIAH/SEMESTER%206/Data%20Warehouse/azko-warehouse/src/dwh/historical_analysis.sql)

---

### 7. Materialized Views (Pre-Aggregated Cubes)

| MV Name | Dimensi | Fungsi |
|---|---|---|
| `mv_monthly_sales` | Time | Ringkasan bulanan (revenue, profit, margin) |
| `mv_category_region` | Product × Store × Time | Cross-analysis kategori dan region |
| `mv_customer_segment` | Customer × Time | Segmentasi membership, usia, gender |
| `mv_store_performance` | Store × Time | Performa toko bulanan |
| `mv_promotion_effectiveness` | Promotion | ROI kampanye promosi |

> [!TIP]
> MV di-refresh otomatis oleh ETL pipeline setelah setiap run. Query dashboard jadi lebih cepat karena data sudah pre-aggregated.

**File:** [materialized_views.sql](file:///d:/KULIAH/SEMESTER%206/Data%20Warehouse/azko-warehouse/src/dwh/materialized_views.sql)

---

## 🚀 Langkah Setup Komponen Baru di Cloud

### Langkah 1 — Jalankan Materialized Views di Neon

1. Buka **Neon Dashboard** → **SQL Editor**
2. Copy-paste isi [materialized_views.sql](file:///d:/KULIAH/SEMESTER%206/Data%20Warehouse/azko-warehouse/src/dwh/materialized_views.sql)
3. Klik **Run**
4. Ini akan membuat 5 Materialized Views yang kosong (akan terisi setelah ETL)

> [!IMPORTANT]
> Jalankan file ini **setelah** `schema_dw.sql` sudah berhasil dijalankan dan ETL sudah pernah dijalankan minimal 1 kali (agar tabel fact_sales sudah ada datanya).

### Langkah 2 — Jalankan ETL (dengan MV Refresh)

ETL pipeline sudah diupdate untuk auto-refresh Materialized Views:

```bash
# Lokal
python src/etl_pipeline.py

# Atau via GitHub Actions (otomatis tiap hari)
```

Output baru yang akan muncul:
```
Refreshing Materialized Views (OLAP cubes)...
  ✓ mv_monthly_sales refreshed
  ✓ mv_category_region refreshed
  ✓ mv_customer_segment refreshed
  ✓ mv_store_performance refreshed
  ✓ mv_promotion_effectiveness refreshed
Materialized Views refresh selesai.
```

### Langkah 3 — Jalankan Query OLAP di Neon / Metabase

Semua query di file berikut bisa langsung dijalankan di **Neon SQL Editor** atau sebagai **Metabase Question (Native Query)**:

1. [olap_cube_queries.sql](file:///d:/KULIAH/SEMESTER%206/Data%20Warehouse/azko-warehouse/src/dwh/olap_cube_queries.sql) — ROLLUP, CUBE, GROUPING SETS
2. [olap_operations.sql](file:///d:/KULIAH/SEMESTER%206/Data%20Warehouse/azko-warehouse/src/dwh/olap_operations.sql) — Drill-Down, Roll-Up, Slice, Dice, Pivot
3. [historical_analysis.sql](file:///d:/KULIAH/SEMESTER%206/Data%20Warehouse/azko-warehouse/src/dwh/historical_analysis.sql) — Tren, Growth, YTD, Seasonality

> [!NOTE]
> Untuk Metabase, gunakan **New Question → Native Query** lalu paste query yang diinginkan. Setiap query terpisah menghasilkan 1 card di dashboard.

### Langkah 4 — Tambahkan Card Dashboard OLAP di Metabase

Selain 7 card dasar sebelumnya, tambahkan card berikut:

| # | Card Baru | Query Source | Tipe Visualisasi |
|---|---|---|---|
| 8 | Revenue by Category × Quarter (Pivot) | `olap_operations.sql` query 5A | Table / Heatmap |
| 9 | Monthly Revenue Trend + Moving Average | `historical_analysis.sql` query 1A | Line Chart (dual axis) |
| 10 | MoM Growth % | `historical_analysis.sql` query 2A | Bar + Line Chart |
| 11 | YTD Cumulative Revenue | `historical_analysis.sql` query 3A | Area Chart |
| 12 | Seasonality Index | `historical_analysis.sql` query 5C | Bar Chart |
| 13 | Weekend vs Weekday | `historical_analysis.sql` query 5B | Bar Chart |

---

## 📁 Struktur Folder Final

```
azko-warehouse/
├── .github/workflows/etl.yml
├── src/
│   ├── oltp/
│   │   ├── schema_sales.sql
│   │   ├── schema_warehouse.sql
│   │   └── schema_marketing.sql
│   ├── dwh/
│   │   ├── schema_dw.sql               ← Star Schema (7 dim + 1 fact)
│   │   ├── materialized_views.sql      ← 5 Pre-Aggregated OLAP Cubes  [NEW]
│   │   ├── olap_cube_queries.sql       ← ROLLUP, CUBE, GROUPING SETS [NEW]
│   │   ├── olap_operations.sql         ← Drill, Roll, Slice, Dice, Pivot [NEW]
│   │   ├── historical_analysis.sql     ← Trend, Growth, YTD, Seasonality [NEW]
│   │   └── analytics_queries.sql       ← 8 query analitik dasar
│   ├── generate_data.py
│   └── etl_pipeline.py                 ← + MV refresh [UPDATED]
├── .env.example
├── .gitignore
└── requirements.txt
```

---

## ✅ Checklist Kelengkapan DWH

```
[x] Design        — Star Schema (7 dimensi + 1 fact table)
[x] ETL           — Full pipeline MySQL → PostgreSQL + MV refresh
[x] Dimension     — dim_time, dim_product, dim_customer, dim_store,
                     dim_supplier, dim_promotion (SCD Type 2), dim_payment_method
[x] Cube (OLAP)   — ROLLUP, CUBE, GROUPING SETS + 5 operasi OLAP
[x] Historical    — Trend, MoM/QoQ, YTD, Moving Avg, Seasonality, Ranking
[x] Materialized  — 5 pre-aggregated views + auto-refresh
```
