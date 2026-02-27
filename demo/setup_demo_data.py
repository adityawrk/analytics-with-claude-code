#!/usr/bin/env python3
"""
Generate realistic sample analytics data and load it into DuckDB.

Usage:
    pip install duckdb
    python setup_demo_data.py

Creates demo/data/analytics_demo.duckdb with four tables:
  - customers  (~2,000 rows)
  - products   (~200 rows)
  - orders     (~10,000 rows)
  - events     (~50,000 rows)

Idempotent — drops and recreates tables on every run.
"""

import duckdb
import random
import hashlib
import os
from datetime import datetime, timedelta

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SEED = 42
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "analytics_demo.duckdb")
DATE_START = datetime(2024, 1, 1)
DATE_END = datetime(2025, 12, 31)

NUM_CUSTOMERS = 2000
NUM_PRODUCTS = 200
NUM_ORDERS = 10000
NUM_EVENTS = 50000

random.seed(SEED)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
FIRST_NAMES = [
    "James", "Mary", "Robert", "Patricia", "John", "Jennifer", "Michael",
    "Linda", "David", "Elizabeth", "William", "Barbara", "Richard", "Susan",
    "Joseph", "Jessica", "Thomas", "Sarah", "Christopher", "Karen", "Daniel",
    "Lisa", "Matthew", "Nancy", "Anthony", "Betty", "Mark", "Margaret",
    "Steven", "Sandra", "Paul", "Ashley", "Andrew", "Dorothy", "Joshua",
    "Kimberly", "Kenneth", "Emily", "Kevin", "Donna", "Brian", "Michelle",
    "George", "Carol", "Timothy", "Amanda", "Ronald", "Melissa", "Edward",
    "Deborah", "Jason", "Stephanie", "Jeffrey", "Rebecca", "Ryan", "Sharon",
    "Jacob", "Laura", "Gary", "Cynthia", "Nicholas", "Kathleen", "Eric",
    "Amy", "Jonathan", "Angela", "Stephen", "Shirley", "Larry", "Anna",
]

LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller",
    "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez",
    "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin",
    "Lee", "Perez", "Thompson", "White", "Harris", "Sanchez", "Clark",
    "Ramirez", "Lewis", "Robinson", "Walker", "Young", "Allen", "King",
    "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores", "Green",
    "Adams", "Nelson", "Baker", "Hall", "Rivera", "Campbell", "Mitchell",
    "Carter", "Roberts", "Chen", "Patel", "Shah", "Kim", "Park", "Singh",
]

CITIES = [
    "New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Philadelphia",
    "San Antonio", "San Diego", "Dallas", "San Jose", "Austin", "Jacksonville",
    "Fort Worth", "Columbus", "Charlotte", "Indianapolis", "San Francisco",
    "Seattle", "Denver", "Washington", "Nashville", "Oklahoma City",
    "El Paso", "Boston", "Portland", "Las Vegas", "Memphis", "Louisville",
    "Baltimore", "Milwaukee",
]

SEGMENTS = ["enterprise", "mid-market", "smb"]
SEGMENT_WEIGHTS = [0.15, 0.30, 0.55]

CATEGORIES = {
    "Electronics": ["Laptops", "Phones", "Tablets", "Accessories", "Audio"],
    "Clothing": ["Tops", "Bottoms", "Outerwear", "Footwear", "Activewear"],
    "Home & Kitchen": ["Cookware", "Furniture", "Decor", "Appliances", "Bedding"],
    "Office Supplies": ["Writing", "Paper", "Organization", "Tech Accessories", "Bags"],
}

PAYMENT_METHODS = ["credit_card", "debit_card", "paypal", "wire_transfer"]
PAYMENT_WEIGHTS = [0.45, 0.25, 0.20, 0.10]

DEVICE_TYPES = ["desktop", "mobile", "tablet"]
DEVICE_WEIGHTS = [0.40, 0.45, 0.15]


def random_date(start, end):
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))


def seasonal_date(start, end):
    """Return a random date biased by seasonal revenue patterns."""
    d = random_date(start, end)
    month = d.month
    # Q4 spike: accept Q4 dates more often; Q1 dip: reject some Q1 dates
    if month in (10, 11, 12):
        return d  # always accept Q4
    if month in (1, 2, 3) and random.random() < 0.30:
        return seasonal_date(start, end)  # retry — creates Q1 dip
    return d


def pareto_choice(items, alpha=1.5):
    """Pick from items with a Pareto-like distribution favoring early indices."""
    idx = int(random.paretovariate(alpha)) % len(items)
    return items[idx]


def make_email(first, last, idx):
    tag = hashlib.md5(f"{first}{last}{idx}".encode()).hexdigest()[:4]
    domain = random.choice(["gmail.com", "yahoo.com", "outlook.com", "company.io", "mail.com"])
    return f"{first.lower()}.{last.lower()}{tag}@{domain}"


# ---------------------------------------------------------------------------
# Data generation
# ---------------------------------------------------------------------------
def generate_customers():
    rows = []
    for i in range(1, NUM_CUSTOMERS + 1):
        first = random.choice(FIRST_NAMES)
        last = random.choice(LAST_NAMES)
        name = f"{first} {last}"
        email = make_email(first, last, i)
        # Plant data quality issue: ~3% null cities
        city = random.choice(CITIES) if random.random() > 0.03 else None
        signup_date = random_date(DATE_START, DATE_END).strftime("%Y-%m-%d")
        segment = random.choices(SEGMENTS, weights=SEGMENT_WEIGHTS, k=1)[0]
        rows.append((i, name, email, city, signup_date, segment))
    return rows


def generate_products():
    rows = []
    pid = 1
    adjectives = ["Pro", "Ultra", "Basic", "Premium", "Lite", "Max", "Classic", "Elite", "Essential", "Advanced"]
    for category, subcats in CATEGORIES.items():
        per_subcat = NUM_PRODUCTS // (len(CATEGORIES) * len(subcats))
        for subcat in subcats:
            for _ in range(per_subcat):
                adj = random.choice(adjectives)
                name = f"{adj} {subcat.rstrip('s')} {pid}"
                cost = round(random.uniform(5, 200), 2)
                # Plant data quality issue: ~3% of products have list_price < cost_price
                if random.random() < 0.03:
                    list_price = round(cost * random.uniform(0.5, 0.9), 2)
                else:
                    list_price = round(cost * random.uniform(1.2, 3.0), 2)
                rows.append((pid, name, category, subcat, cost, list_price))
                pid += 1
    # Fill remaining to hit ~200
    while len(rows) < NUM_PRODUCTS:
        cat = random.choice(list(CATEGORIES.keys()))
        subcat = random.choice(CATEGORIES[cat])
        adj = random.choice(adjectives)
        name = f"{adj} {subcat.rstrip('s')} {pid}"
        cost = round(random.uniform(5, 200), 2)
        list_price = round(cost * random.uniform(1.2, 3.0), 2)
        rows.append((pid, name, cat, subcat, cost, list_price))
        pid += 1
    return rows


def generate_orders(customers, products):
    rows = []
    customer_ids = [c[0] for c in customers]
    product_ids = [p[0] for p in products]
    product_prices = {p[0]: p[5] for p in products}  # list_price

    duplicate_target = random.randint(8050, 8150)  # plant a few duplicate order_ids

    for i in range(1, NUM_ORDERS + 1):
        cid = pareto_choice(customer_ids, alpha=1.2)
        pid = random.choice(product_ids)
        order_date = seasonal_date(DATE_START, DATE_END).strftime("%Y-%m-%d")
        quantity = random.choices([1, 2, 3, 4, 5], weights=[50, 25, 15, 7, 3], k=1)[0]
        unit_price = product_prices[pid]
        total = round(unit_price * quantity, 2)

        # ~15% cancelled/returned
        r = random.random()
        if r < 0.10:
            status = "cancelled"
        elif r < 0.15:
            status = "returned"
        else:
            status = "completed"

        pm = random.choices(PAYMENT_METHODS, weights=PAYMENT_WEIGHTS, k=1)[0]
        rows.append((i, cid, order_date, pid, quantity, unit_price, total, status, pm))

    # Plant data quality issue: duplicate a few orders with the same order_id
    for dup_offset in range(5):
        src = rows[duplicate_target + dup_offset]
        rows.append(src)  # exact duplicate row

    return rows


def generate_events(customers):
    rows = []
    customer_ids = [c[0] for c in customers]
    eid = 1
    session_counter = 1

    while eid <= NUM_EVENTS:
        cid = pareto_choice(customer_ids, alpha=1.2)
        device = random.choices(DEVICE_TYPES, weights=DEVICE_WEIGHTS, k=1)[0]
        session_id = f"sess_{session_counter:06d}"
        session_counter += 1
        base_date = random_date(DATE_START, DATE_END)

        # Simulate a funnel within this session
        # page_view always happens
        rows.append((eid, cid, "page_view", base_date.strftime("%Y-%m-%d %H:%M:%S"), session_id, device))
        eid += 1
        if eid > NUM_EVENTS:
            break

        # add_to_cart: 30% of page_views
        if random.random() < 0.30:
            ts = (base_date + timedelta(minutes=random.randint(1, 10))).strftime("%Y-%m-%d %H:%M:%S")
            rows.append((eid, cid, "add_to_cart", ts, session_id, device))
            eid += 1
            if eid > NUM_EVENTS:
                break

            # checkout_start: 50% of add_to_carts
            if random.random() < 0.50:
                ts = (base_date + timedelta(minutes=random.randint(11, 20))).strftime("%Y-%m-%d %H:%M:%S")
                rows.append((eid, cid, "checkout_start", ts, session_id, device))
                eid += 1
                if eid > NUM_EVENTS:
                    break

                # purchase: 70% of checkouts
                if random.random() < 0.70:
                    ts = (base_date + timedelta(minutes=random.randint(21, 30))).strftime("%Y-%m-%d %H:%M:%S")
                    rows.append((eid, cid, "purchase", ts, session_id, device))
                    eid += 1
                    if eid > NUM_EVENTS:
                        break

    return rows


# ---------------------------------------------------------------------------
# Load into DuckDB
# ---------------------------------------------------------------------------
def load_data():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

    print("Generating sample data...")
    customers = generate_customers()
    products = generate_products()
    orders = generate_orders(customers, products)
    events = generate_events(customers)

    print(f"Connecting to {DB_PATH}")
    con = duckdb.connect(DB_PATH)

    # Drop existing tables
    for table in ["events", "orders", "products", "customers"]:
        con.execute(f"DROP TABLE IF EXISTS {table}")

    # Create tables
    con.execute("""
        CREATE TABLE customers (
            customer_id INTEGER PRIMARY KEY,
            name VARCHAR,
            email VARCHAR,
            city VARCHAR,
            signup_date DATE,
            segment VARCHAR
        )
    """)
    con.execute("""
        CREATE TABLE products (
            product_id INTEGER PRIMARY KEY,
            name VARCHAR,
            category VARCHAR,
            subcategory VARCHAR,
            cost_price DECIMAL(10,2),
            list_price DECIMAL(10,2)
        )
    """)
    con.execute("""
        CREATE TABLE orders (
            order_id INTEGER,
            customer_id INTEGER,
            order_date DATE,
            product_id INTEGER,
            quantity INTEGER,
            unit_price DECIMAL(10,2),
            total_amount DECIMAL(10,2),
            status VARCHAR,
            payment_method VARCHAR
        )
    """)
    con.execute("""
        CREATE TABLE events (
            event_id INTEGER,
            customer_id INTEGER,
            event_type VARCHAR,
            event_date TIMESTAMP,
            session_id VARCHAR,
            device_type VARCHAR
        )
    """)

    # Insert data
    print("Loading customers...")
    con.executemany("INSERT INTO customers VALUES (?, ?, ?, ?, ?, ?)", customers)

    print("Loading products...")
    con.executemany("INSERT INTO products VALUES (?, ?, ?, ?, ?, ?)", products)

    print("Loading orders...")
    con.executemany("INSERT INTO orders VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", orders)

    print("Loading events...")
    con.executemany("INSERT INTO events VALUES (?, ?, ?, ?, ?, ?)", events)

    # Print summary
    print("\n" + "=" * 60)
    print("  DEMO DATABASE READY")
    print("=" * 60)

    for table in ["customers", "products", "orders", "events"]:
        count = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        print(f"  {table:12s}  {count:>8,} rows")

    date_range = con.execute("SELECT MIN(order_date), MAX(order_date) FROM orders").fetchone()
    print(f"\n  Order date range: {date_range[0]} to {date_range[1]}")

    rev = con.execute(
        "SELECT ROUND(SUM(total_amount), 2) FROM orders WHERE status = 'completed'"
    ).fetchone()[0]
    print(f"  Total completed revenue: ${rev:,.2f}")

    cancel_rate = con.execute(
        "SELECT ROUND(100.0 * SUM(CASE WHEN status != 'completed' THEN 1 ELSE 0 END) / COUNT(*), 1) FROM orders"
    ).fetchone()[0]
    print(f"  Cancellation/return rate: {cancel_rate}%")

    null_cities = con.execute(
        "SELECT COUNT(*) FROM customers WHERE city IS NULL"
    ).fetchone()[0]
    print(f"  Customers with null city: {null_cities}")

    mispriced = con.execute(
        "SELECT COUNT(*) FROM products WHERE list_price < cost_price"
    ).fetchone()[0]
    print(f"  Products with list < cost: {mispriced}")

    dup_orders = con.execute(
        "SELECT COUNT(*) - COUNT(DISTINCT order_id) FROM orders"
    ).fetchone()[0]
    print(f"  Duplicate order rows: {dup_orders}")

    funnel = con.execute("""
        SELECT event_type, COUNT(*) as cnt
        FROM events
        GROUP BY event_type
        ORDER BY cnt DESC
    """).fetchall()
    print("\n  Funnel breakdown:")
    for event_type, cnt in funnel:
        print(f"    {event_type:20s}  {cnt:>8,}")

    print(f"\n  Database file: {DB_PATH}")
    print("  Ready to use with Claude Code!\n")

    con.close()


if __name__ == "__main__":
    load_data()
