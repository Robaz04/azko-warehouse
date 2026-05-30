from faker import Faker
import random
from datetime import datetime, timedelta
from sqlalchemy import create_engine, text

fake = Faker("id_ID")

# SESUAIKAN USERNAME PASSWORD MYSQL KAMU
MYSQL_USER = "root"
MYSQL_PASSWORD = ""
MYSQL_HOST = "localhost"
MYSQL_PORT = "3306"

sales_engine = create_engine(f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}@{MYSQL_HOST}:{MYSQL_PORT}/azko_sales_db")
warehouse_engine = create_engine(f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}@{MYSQL_HOST}:{MYSQL_PORT}/azko_warehouse_db")
marketing_engine = create_engine(f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}@{MYSQL_HOST}:{MYSQL_PORT}/azko_marketing_db")

cities = ["Jakarta", "Bandung", "Surabaya", "Medan", "Semarang", "Yogyakarta", "Bekasi", "Tangerang", "Depok", "Bogor"]
provinces = ["DKI Jakarta", "Jawa Barat", "Jawa Timur", "Sumatera Utara", "Jawa Tengah", "DI Yogyakarta", "Banten"]
regions = ["Barat", "Tengah", "Timur"]
categories = ["Kitchenware", "Home Decor", "Cleaning Tools", "Furniture", "Bathroom", "Electrical", "Storage"]
brands = ["Krisbow", "Ace", "Azko Living", "Tactix", "Selma", "Toyomi", "Sharp"]
payment_methods = ["Cash", "Debit Card", "Credit Card", "E-Wallet", "Bank Transfer"]

def random_date(start, end):
    delta = end - start
    return start + timedelta(days=random.randint(0, delta.days))

def insert_many(engine, table, rows):
    if not rows:
        return
    columns = rows[0].keys()
    col_names = ", ".join(columns)
    placeholders = ", ".join([f":{col}" for col in columns])
    query = text(f"INSERT INTO {table} ({col_names}) VALUES ({placeholders})")
    with engine.begin() as conn:
        conn.execute(query, rows)

# =========================
# 1. SALES MASTER DATA
# =========================

stores = []
for i in range(1, 21):
    city = random.choice(cities)
    stores.append({
        "store_id": f"ST{i:03d}",
        "store_name": f"AZKO {city} {i}",
        "store_type": random.choice(["Mall Store", "Standalone Store"]),
        "city": city,
        "province": random.choice(provinces),
        "region": random.choice(regions)
    })

customers = []
for i in range(1, 501):
    customers.append({
        "customer_id": f"CUST{i:04d}",
        "customer_name": fake.name(),
        "gender": random.choice(["Male", "Female"]),
        "age": random.randint(18, 60),
        "city": random.choice(cities),
        "membership_level": random.choice(["Regular", "Silver", "Gold", "Platinum"]),
        "registration_date": random_date(datetime(2022, 1, 1), datetime(2025, 12, 31)).date()
    })

insert_many(sales_engine, "stores", stores)
insert_many(sales_engine, "customers", customers)

# =========================
# 2. WAREHOUSE MASTER DATA
# =========================

suppliers = []
for i in range(1, 21):
    suppliers.append({
        "supplier_id": f"SUP{i:03d}",
        "supplier_name": f"Supplier {fake.company()}",
        "supplier_city": random.choice(cities),
        "supplier_category": random.choice(categories),
        "contact_person": fake.name(),
        "supplier_status": random.choice(["Active", "Inactive"])
    })

products = []
for i in range(1, 101):
    cost_price = random.randint(20000, 1500000)
    unit_price = int(cost_price * random.uniform(1.2, 1.8))
    products.append({
        "product_id": f"PRD{i:04d}",
        "product_name": f"{random.choice(brands)} {random.choice(categories)} {i}",
        "category": random.choice(categories),
        "brand": random.choice(brands),
        "supplier_id": random.choice(suppliers)["supplier_id"],
        "unit_price": unit_price,
        "cost_price": cost_price,
        "product_status": random.choice(["Active", "Active", "Active", "Discontinued"])
    })

insert_many(warehouse_engine, "suppliers", suppliers)
insert_many(warehouse_engine, "products", products)

# =========================
# 3. MARKETING MASTER DATA
# =========================

campaigns = []
for i in range(1, 11):
    start_date = random_date(datetime(2025, 1, 1), datetime(2025, 10, 1)).date()
    end_date = start_date + timedelta(days=random.randint(14, 60))
    campaigns.append({
        "campaign_id": f"CAM{i:03d}",
        "campaign_name": f"AZKO Campaign {i}",
        "campaign_type": random.choice(["Discount", "Bundle", "Cashback", "Loyalty"]),
        "start_date": start_date,
        "end_date": end_date,
        "channel": random.choice(["Store", "Instagram", "Website", "Email"]),
        "campaign_budget": random.randint(5_000_000, 50_000_000),
        "target_segment": random.choice(["Regular", "Silver", "Gold", "Platinum", "All Customers"])
    })

insert_many(marketing_engine, "marketing_campaigns", campaigns)

# =========================
# 4. SALES TRANSACTIONS
# =========================

transactions = []
transaction_details = []

for i in range(1, 1001):
    transaction_id = f"TRX{i:05d}"
    transaction_date = random_date(datetime(2025, 1, 1), datetime(2025, 12, 31)).date()
    store = random.choice(stores)
    customer = random.choice(customers)
    payment_method = random.choice(payment_methods)
    status = random.choice(["Success", "Success", "Success", "Cancelled", "Returned"])

    item_count = random.randint(1, 5)
    selected_products = random.sample(products, item_count)

    total_amount = 0
    discount_amount = 0

    for j, product in enumerate(selected_products, start=1):
        quantity = random.randint(1, 4)
        unit_price = float(product["unit_price"])
        discount_per_item = random.choice([0, 0, 0, 5000, 10000, 20000])
        subtotal = (unit_price - discount_per_item) * quantity

        total_amount += unit_price * quantity
        discount_amount += discount_per_item * quantity

        transaction_details.append({
            "detail_id": f"DTL{i:05d}{j:02d}",
            "transaction_id": transaction_id,
            "product_id": product["product_id"],
            "quantity": quantity,
            "unit_price": unit_price,
            "discount_per_item": discount_per_item,
            "subtotal": subtotal
        })

    final_amount = total_amount - discount_amount

    transactions.append({
        "transaction_id": transaction_id,
        "transaction_date": transaction_date,
        "store_id": store["store_id"],
        "customer_id": customer["customer_id"],
        "employee_id": f"EMP{random.randint(1, 100):03d}",
        "payment_method": payment_method,
        "total_amount": total_amount,
        "discount_amount": discount_amount,
        "final_amount": final_amount,
        "transaction_status": status
    })

insert_many(sales_engine, "sales_transactions", transactions)
insert_many(sales_engine, "sales_transaction_details", transaction_details)

# =========================
# 5. INVENTORY AND SHIPMENT
# =========================

inventory_rows = []
stock_id = 1

for store in stores:
    for product in random.sample(products, 50):
        beginning_stock = random.randint(20, 200)
        stock_in = random.randint(0, 80)
        stock_out = random.randint(0, 100)
        ending_stock = max(0, beginning_stock + stock_in - stock_out)

        if ending_stock == 0:
            stock_status = "Out of Stock"
        elif ending_stock < 20:
            stock_status = "Low"
        else:
            stock_status = "Safe"

        inventory_rows.append({
            "stock_id": f"STK{stock_id:05d}",
            "product_id": product["product_id"],
            "store_id": store["store_id"],
            "stock_date": random_date(datetime(2025, 1, 1), datetime(2025, 12, 31)).date(),
            "beginning_stock": beginning_stock,
            "stock_in": stock_in,
            "stock_out": stock_out,
            "ending_stock": ending_stock,
            "stock_status": stock_status
        })
        stock_id += 1

shipments = []
for i in range(1, 501):
    shipments.append({
        "shipment_id": f"SHP{i:05d}",
        "shipment_date": random_date(datetime(2025, 1, 1), datetime(2025, 12, 31)).date(),
        "source_location": random.choice(["Gudang Jakarta", "Gudang Bandung", "Gudang Surabaya"]),
        "destination_store_id": random.choice(stores)["store_id"],
        "product_id": random.choice(products)["product_id"],
        "quantity_shipped": random.randint(10, 100),
        "shipping_cost": random.randint(100000, 1500000),
        "shipment_status": random.choice(["Delivered", "Delivered", "Delivered", "Delayed", "Cancelled"])
    })

insert_many(warehouse_engine, "inventory_stock", inventory_rows)
insert_many(warehouse_engine, "shipments", shipments)

# =========================
# 6. MARKETING SUPPORT DATA
# =========================

promotion_usage = []
feedback_rows = []

success_transactions = [t for t in transactions if t["transaction_status"] == "Success"]

for i in range(1, 401):
    trx = random.choice(success_transactions)
    campaign = random.choice(campaigns)
    promotion_usage.append({
        "promo_usage_id": f"PRU{i:05d}",
        "campaign_id": campaign["campaign_id"],
        "transaction_id": trx["transaction_id"],
        "customer_id": trx["customer_id"],
        "promo_code": f"PROMO{random.randint(10, 99)}",
        "discount_value": random.choice([10000, 20000, 30000, 50000]),
        "usage_date": trx["transaction_date"]
    })

review_templates = {
    "Positive": [
        "Produk bagus dan sesuai kebutuhan.",
        "Pelayanan toko sangat baik.",
        "Barang berkualitas dan pengiriman cepat."
    ],
    "Neutral": [
        "Produk cukup baik, sesuai harga.",
        "Pengalaman belanja biasa saja.",
        "Barang cukup sesuai ekspektasi."
    ],
    "Negative": [
        "Stok barang kurang lengkap.",
        "Pengiriman cukup lama.",
        "Produk tidak sesuai harapan."
    ]
}

for i in range(1, 501):
    trx = random.choice(success_transactions)
    related_details = [d for d in transaction_details if d["transaction_id"] == trx["transaction_id"]]
    product_id = random.choice(related_details)["product_id"]

    sentiment = random.choice(["Positive", "Positive", "Neutral", "Negative"])
    rating = {
        "Positive": random.choice([4, 5]),
        "Neutral": random.choice([3]),
        "Negative": random.choice([1, 2])
    }[sentiment]

    feedback_rows.append({
        "feedback_id": f"FDB{i:05d}",
        "customer_id": trx["customer_id"],
        "transaction_id": trx["transaction_id"],
        "product_id": product_id,
        "feedback_date": trx["transaction_date"] + timedelta(days=random.randint(1, 14)),
        "rating": rating,
        "review_text": random.choice(review_templates[sentiment]),
        "sentiment": sentiment,
        "feedback_channel": random.choice(["Website", "App", "Google Review", "Social Media"])
    })

insert_many(marketing_engine, "promotion_usage", promotion_usage)
insert_many(marketing_engine, "customer_feedback", feedback_rows)

print("Generate dummy data berhasil!")
print(f"Stores: {len(stores)}")
print(f"Customers: {len(customers)}")
print(f"Suppliers: {len(suppliers)}")
print(f"Products: {len(products)}")
print(f"Campaigns: {len(campaigns)}")
print(f"Transactions: {len(transactions)}")
print(f"Transaction Details: {len(transaction_details)}")
print(f"Inventory Rows: {len(inventory_rows)}")
print(f"Shipments: {len(shipments)}")
print(f"Promotion Usage: {len(promotion_usage)}")
print(f"Feedback Rows: {len(feedback_rows)}")