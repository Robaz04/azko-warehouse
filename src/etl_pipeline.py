"""
ETL Pipeline: Extract dari MySQL OLTP → Transform → Load ke PostgreSQL DWH
Dijalankan oleh GitHub Actions tiap hari otomatis.

Stack: MySQL (Railway) → Python ETL → PostgreSQL (Neon.tech)
"""

import os
import logging
from datetime import datetime, timedelta
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
import pandas as pd

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)


# ── Koneksi ───────────────────────────────────────────────────────────────────

def get_sales_engine():
    return create_engine(
        f"mysql+pymysql://{os.getenv('SALES_DB_USER')}:{os.getenv('SALES_DB_PASS')}"
        f"@{os.getenv('SALES_DB_HOST')}:{os.getenv('SALES_DB_PORT', 3306)}"
        f"/{os.getenv('SALES_DB_NAME', 'azko_sales_db')}"
    )

def get_warehouse_engine():
    return create_engine(
        f"mysql+pymysql://{os.getenv('WAREHOUSE_DB_USER')}:{os.getenv('WAREHOUSE_DB_PASS')}"
        f"@{os.getenv('WAREHOUSE_DB_HOST')}:{os.getenv('WAREHOUSE_DB_PORT', 3306)}"
        f"/{os.getenv('WAREHOUSE_DB_NAME', 'azko_warehouse_db')}"
    )

def get_marketing_engine():
    return create_engine(
        f"mysql+pymysql://{os.getenv('MARKETING_DB_USER')}:{os.getenv('MARKETING_DB_PASS')}"
        f"@{os.getenv('MARKETING_DB_HOST')}:{os.getenv('MARKETING_DB_PORT', 3306)}"
        f"/{os.getenv('MARKETING_DB_NAME', 'azko_marketing_db')}"
    )

def get_dwh_engine():
    url = os.getenv("DWH_DATABASE_URL")
    if not url:
        raise ValueError("DWH_DATABASE_URL environment variable is not set!")
    return create_engine(url)


# ── LOAD dim_time ─────────────────────────────────────────────────────────────

def load_dim_time(dwh):
    log.info("Loading dim_time...")
    month_names = ["Januari","Februari","Maret","April","Mei","Juni",
                   "Juli","Agustus","September","Oktober","November","Desember"]
    day_names   = ["Senin","Selasa","Rabu","Kamis","Jumat","Sabtu","Minggu"]

    rows = []
    for i in range(730):  # 2 tahun: 2025-2026
        d = datetime(2025, 1, 1) + timedelta(days=i)
        rows.append({
            "full_date":    d.date(),
            "day":          d.day,
            "month":        d.month,
            "month_name":   month_names[d.month - 1],
            "quarter":      (d.month - 1) // 3 + 1,
            "year":         d.year,
            "week_of_year": d.isocalendar()[1],
            "day_of_week":  d.weekday(),
            "day_name":     day_names[d.weekday()],
            "is_weekend":   d.weekday() >= 5
        })

    df = pd.DataFrame(rows)
    with dwh.begin() as conn:
        conn.execute(text("DELETE FROM fact_sales"))  # hapus fact dulu (FK constraint)
        conn.execute(text("DELETE FROM dim_time"))
    df.to_sql("dim_time", dwh, if_exists="append", index=False)
    log.info(f"  ✓ dim_time: {len(df)} baris")


# ── LOAD dim_product ──────────────────────────────────────────────────────────

def load_dim_product(wh_engine, dwh):
    log.info("Loading dim_product...")
    df = pd.read_sql("SELECT * FROM products", wh_engine)
    df = df[["product_id","product_name","category","brand",
             "unit_price","cost_price","product_status"]]

    with dwh.begin() as conn:
        conn.execute(text("DELETE FROM dim_product"))
    df.to_sql("dim_product", dwh, if_exists="append", index=False)
    log.info(f"  ✓ dim_product: {len(df)} baris")


# ── LOAD dim_customer ─────────────────────────────────────────────────────────

def load_dim_customer(sales_engine, dwh):
    log.info("Loading dim_customer...")
    df = pd.read_sql("SELECT * FROM customers", sales_engine)

    def age_group(age):
        if age < 26:   return "Youth (< 26)"
        if age < 40:   return "Adult (26-39)"
        if age < 55:   return "Middle (40-54)"
        return "Senior (55+)"

    df["age_group"] = df["age"].apply(age_group)
    df = df[["customer_id","customer_name","gender","age","age_group",
             "city","membership_level","registration_date"]]

    with dwh.begin() as conn:
        conn.execute(text("DELETE FROM dim_customer"))
    df.to_sql("dim_customer", dwh, if_exists="append", index=False)
    log.info(f"  ✓ dim_customer: {len(df)} baris")


# ── LOAD dim_store ────────────────────────────────────────────────────────────

def load_dim_store(sales_engine, dwh):
    log.info("Loading dim_store...")
    df = pd.read_sql("SELECT * FROM stores", sales_engine)
    df = df[["store_id","store_name","store_type","city","province","region"]]

    with dwh.begin() as conn:
        conn.execute(text("DELETE FROM dim_store"))
    df.to_sql("dim_store", dwh, if_exists="append", index=False)
    log.info(f"  ✓ dim_store: {len(df)} baris")


# ── LOAD dim_supplier ─────────────────────────────────────────────────────────

def load_dim_supplier(wh_engine, dwh):
    log.info("Loading dim_supplier...")
    df = pd.read_sql("SELECT * FROM suppliers", wh_engine)
    df = df[["supplier_id","supplier_name","supplier_city",
             "supplier_category","supplier_status"]]

    with dwh.begin() as conn:
        conn.execute(text("DELETE FROM dim_supplier"))
    df.to_sql("dim_supplier", dwh, if_exists="append", index=False)
    log.info(f"  ✓ dim_supplier: {len(df)} baris")


# ── LOAD dim_promotion ────────────────────────────────────────────────────────

def load_dim_promotion(mkt_engine, dwh):
    log.info("Loading dim_promotion...")
    df = pd.read_sql("SELECT * FROM marketing_campaigns", mkt_engine)
    df = df.rename(columns={"start_date": "effective_date", "end_date": "expiry_date"})
    df = df[["campaign_id","campaign_name","campaign_type",
             "channel","target_segment","effective_date","expiry_date"]]
    df["is_current"] = True

    with dwh.begin() as conn:
        conn.execute(text("DELETE FROM dim_promotion WHERE campaign_id != 'NO_PROMO'"))

    # Pastikan row "No Promotion" ada
    with dwh.begin() as conn:
        conn.execute(text("""
            INSERT INTO dim_promotion
                (campaign_id, campaign_name, campaign_type, channel,
                 target_segment, effective_date, expiry_date, is_current)
            VALUES ('NO_PROMO','No Promotion','none','none',
                    'All','2000-01-01','2099-12-31',TRUE)
            ON CONFLICT DO NOTHING
        """))

    df.to_sql("dim_promotion", dwh, if_exists="append", index=False)
    log.info(f"  ✓ dim_promotion: {len(df)} baris")


# ── LOAD dim_payment_method ───────────────────────────────────────────────────

def load_dim_payment_method(dwh):
    log.info("Loading dim_payment_method...")
    payment_map = [
        ("Cash",          "cash"),
        ("Debit Card",    "card"),
        ("Credit Card",   "card"),
        ("E-Wallet",      "digital"),
        ("Bank Transfer", "digital"),
    ]
    df = pd.DataFrame(payment_map, columns=["payment_method","payment_type"])

    with dwh.begin() as conn:
        conn.execute(text("DELETE FROM dim_payment_method"))
    df.to_sql("dim_payment_method", dwh, if_exists="append", index=False)
    log.info(f"  ✓ dim_payment_method: {len(df)} baris")


# ── LOAD fact_sales ───────────────────────────────────────────────────────────

def load_fact_sales(sales_engine, wh_engine, mkt_engine, dwh):
    log.info("Loading fact_sales (proses utama)...")

    # Extract dari OLTP
    trx   = pd.read_sql("SELECT * FROM sales_transactions WHERE transaction_status = 'Success'", sales_engine)
    dtl   = pd.read_sql("SELECT * FROM sales_transaction_details", sales_engine)
    prods = pd.read_sql("SELECT product_id, cost_price, supplier_id FROM products", wh_engine)
    promo = pd.read_sql(
        "SELECT transaction_id, campaign_id FROM promotion_usage GROUP BY transaction_id, campaign_id",
        mkt_engine
    )

    # Join detail → transaksi → produk
    df = dtl.merge(trx[["transaction_id","transaction_date","store_id",
                         "customer_id","payment_method"]], on="transaction_id")
    df = df.merge(prods, on="product_id")

    # Tambahkan promo (left join — transaksi tanpa promo → NO_PROMO)
    df = df.merge(promo, on="transaction_id", how="left")
    df["campaign_id"] = df["campaign_id"].fillna("NO_PROMO")

    # ── Lookup Keys dari Dimensi ──────────────────────────────────────────────

    time_lkp    = pd.read_sql("SELECT time_key, full_date FROM dim_time", dwh)
    time_lkp["full_date"] = pd.to_datetime(time_lkp["full_date"]).dt.date
    prod_lkp    = pd.read_sql("SELECT product_key, product_id FROM dim_product", dwh)
    cust_lkp    = pd.read_sql("SELECT customer_key, customer_id FROM dim_customer", dwh)
    store_lkp   = pd.read_sql("SELECT store_key, store_id FROM dim_store", dwh)
    supp_lkp    = pd.read_sql("SELECT supplier_key, supplier_id FROM dim_supplier", dwh)
    promo_lkp   = pd.read_sql("SELECT promotion_key, campaign_id FROM dim_promotion WHERE is_current = TRUE", dwh)
    pay_lkp     = pd.read_sql("SELECT payment_key, payment_method FROM dim_payment_method", dwh)

    # Normalisasi tipe data untuk join
    df["transaction_date"] = pd.to_datetime(df["transaction_date"]).dt.date

    df = (df
        .merge(time_lkp,  left_on="transaction_date", right_on="full_date")
        .merge(prod_lkp,  on="product_id")
        .merge(cust_lkp,  on="customer_id")
        .merge(store_lkp, on="store_id")
        .merge(supp_lkp,  on="supplier_id")
        .merge(promo_lkp, on="campaign_id")
        .merge(pay_lkp,   on="payment_method")
    )

    # ── Hitung Measures ───────────────────────────────────────────────────────
    df["cost_amount"]     = df["cost_price"] * df["quantity"]
    df["total_sales"]     = df["unit_price"]  * df["quantity"]
    df["discount_amount"] = df["discount_per_item"] * df["quantity"]
    df["final_sales"]     = df["subtotal"]
    df["gross_profit"]    = df["final_sales"] - df["cost_amount"]

    # ── Pilih Kolom Final ─────────────────────────────────────────────────────
    fact = df[[
        "time_key","product_key","customer_key","store_key",
        "promotion_key","supplier_key","payment_key",
        "transaction_id","detail_id",
        "quantity","unit_price","discount_amount",
        "total_sales","final_sales","cost_amount","gross_profit"
    ]].rename(columns={"quantity": "quantity_sold"})

    with dwh.begin() as conn:
        conn.execute(text("DELETE FROM fact_sales"))
    fact.to_sql("fact_sales", dwh, if_exists="append", index=False, chunksize=1000)
    log.info(f"  ✓ fact_sales: {len(fact)} baris")


# ── Refresh Materialized Views ────────────────────────────────────────────────

def refresh_materialized_views(dwh):
    """Refresh semua Materialized Views setelah ETL selesai.
    MV berfungsi sebagai pre-aggregated OLAP cubes untuk performa dashboard."""
    log.info("Refreshing Materialized Views (OLAP cubes)...")

    mv_list = [
        "mv_monthly_sales",
        "mv_category_region",
        "mv_customer_segment",
        "mv_store_performance",
        "mv_promotion_effectiveness",
    ]

    with dwh.begin() as conn:
        for mv_name in mv_list:
            try:
                conn.execute(text(f"REFRESH MATERIALIZED VIEW CONCURRENTLY {mv_name}"))
                log.info(f"  ✓ {mv_name} refreshed")
            except Exception as e:
                # Jika MV belum dibuat, skip (non-fatal)
                log.warning(f"  ⚠ {mv_name} skip: {e}")

    log.info("Materialized Views refresh selesai.")


# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    log.info("═══ AZKO DWH ETL Pipeline Dimulai ═══")

    sales     = get_sales_engine()
    warehouse = get_warehouse_engine()
    marketing = get_marketing_engine()
    dwh       = get_dwh_engine()

    # Load dimensi terlebih dahulu
    load_dim_time(dwh)
    load_dim_product(warehouse, dwh)
    load_dim_customer(sales, dwh)
    load_dim_store(sales, dwh)
    load_dim_supplier(warehouse, dwh)
    load_dim_promotion(marketing, dwh)
    load_dim_payment_method(dwh)

    # Load fact table (terakhir, karena bergantung pada semua dimensi)
    load_fact_sales(sales, warehouse, marketing, dwh)

    # Refresh Materialized Views (pre-aggregated OLAP cubes)
    refresh_materialized_views(dwh)

    log.info("═══ ETL Selesai! Data Warehouse siap. ═══")
