import os
import random
import time
from datetime import datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP

import mysql.connector


SEGMENTS = ["SMB", "MID_MARKET", "ENTERPRISE"]
CUSTOMERS = [
    ("CUST-1001", "Ava Chen", "ava.chen@example.com"),
    ("CUST-1002", "Liam Patel", "liam.patel@example.com"),
    ("CUST-1003", "Sophia Nguyen", "sophia.nguyen@example.com"),
    ("CUST-1004", "Noah Brown", "noah.brown@example.com"),
]
PRODUCTS = [
    ("SKU-100", "Wireless Mouse"),
    ("SKU-101", "Mechanical Keyboard"),
    ("SKU-102", "4K Monitor"),
    ("SKU-103", "USB-C Dock"),
    ("SKU-104", "Noise Cancelling Headset"),
]


def money(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def mysql_connection() -> mysql.connector.MySQLConnection:
    return mysql.connector.connect(
        host=os.getenv("MDM_MYSQL_HOST", "mysql-mdm"),
        port=int(os.getenv("MDM_MYSQL_PORT", "3306")),
        user=os.getenv("MDM_MYSQL_USER", "root"),
        password=os.getenv("MDM_MYSQL_PASSWORD", "mdmroot"),
        database=os.getenv("MDM_MYSQL_DB", "mdm"),
        autocommit=False,
    )


def upsert_customer(cursor: mysql.connector.cursor.MySQLCursor) -> None:
    customer_id, name, email = random.choice(CUSTOMERS)
    now = datetime.utcnow()
    first_seen = now - timedelta(days=random.randint(7, 180))
    last_seen = now - timedelta(days=random.randint(0, 7))
    projected_order_count = random.randint(1, 40)
    projected_total_spent = money(Decimal(str(random.uniform(100, 10000))))

    cursor.execute(
        """
        INSERT INTO customer360 (
          customer_id,
          customer_name,
          customer_email,
          customer_segment,
          currency,
          first_order_timestamp,
          last_order_timestamp,
          projected_order_count,
          projected_total_spent,
          projection_updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE
          customer_name = VALUES(customer_name),
          customer_email = VALUES(customer_email),
          customer_segment = VALUES(customer_segment),
          currency = VALUES(currency),
          first_order_timestamp = VALUES(first_order_timestamp),
          last_order_timestamp = VALUES(last_order_timestamp),
          projected_order_count = VALUES(projected_order_count),
          projected_total_spent = VALUES(projected_total_spent),
          projection_updated_at = VALUES(projection_updated_at)
        """,
        (
            customer_id,
            name,
            email,
            random.choice(SEGMENTS),
            "USD",
            first_seen,
            last_seen,
            projected_order_count,
            str(projected_total_spent),
            now,
        ),
    )


def upsert_product(cursor: mysql.connector.cursor.MySQLCursor) -> None:
    product_id, product_name = random.choice(PRODUCTS)
    now = datetime.utcnow()
    first_seen = now - timedelta(days=random.randint(14, 365))
    last_seen = now - timedelta(days=random.randint(0, 14))
    orders_count = random.randint(5, 200)
    units_sold = random.randint(orders_count, orders_count * 5)
    avg_unit_price = money(Decimal(str(random.uniform(10, 600))))

    cursor.execute(
        """
        INSERT INTO product_master (
          product_id,
          product_name,
          currency,
          first_seen_at,
          last_seen_at,
          orders_count,
          units_sold,
          avg_unit_price
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE
          product_name = VALUES(product_name),
          currency = VALUES(currency),
          first_seen_at = VALUES(first_seen_at),
          last_seen_at = VALUES(last_seen_at),
          orders_count = VALUES(orders_count),
          units_sold = VALUES(units_sold),
          avg_unit_price = VALUES(avg_unit_price)
        """,
        (
            product_id,
            product_name,
            "USD",
            first_seen,
            last_seen,
            orders_count,
            units_sold,
            str(avg_unit_price),
        ),
    )


def main() -> None:
    interval_ms = int(os.getenv("MDM_WRITE_INTERVAL_MS", "3000"))

    while True:
        try:
            conn = mysql_connection()
            cursor = conn.cursor()
            upsert_customer(cursor)
            upsert_product(cursor)
            conn.commit()
            cursor.close()
            conn.close()
            print("upserted customer360 and product_master rows", flush=True)
            time.sleep(interval_ms / 1000)
        except mysql.connector.Error as exc:
            print(f"mysql unavailable, retrying: {exc}", flush=True)
            time.sleep(2)


if __name__ == "__main__":
    main()
