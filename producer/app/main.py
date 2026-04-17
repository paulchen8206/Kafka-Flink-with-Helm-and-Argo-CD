import json
import os
import random
import time
import uuid
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP

from kafka import KafkaProducer


SEGMENTS = ["SMB", "MID_MARKET", "ENTERPRISE"]
PRODUCTS = [
    ("SKU-100", "Wireless Mouse", Decimal("29.99")),
    ("SKU-101", "Mechanical Keyboard", Decimal("89.00")),
    ("SKU-102", "4K Monitor", Decimal("399.99")),
    ("SKU-103", "USB-C Dock", Decimal("149.50")),
    ("SKU-104", "Noise Cancelling Headset", Decimal("215.75")),
]
FIRST_NAMES = ["Ava", "Lucas", "Sophia", "Noah", "Emma", "Liam"]
LAST_NAMES = ["Chen", "Singh", "Patel", "Nguyen", "Garcia", "Brown"]


def money(value: Decimal) -> str:
    return str(value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))


def random_customer() -> dict:
    first_name = random.choice(FIRST_NAMES)
    last_name = random.choice(LAST_NAMES)
    customer_id = f"CUST-{random.randint(1000, 9999)}"
    return {
        "customerId": customer_id,
        "firstName": first_name,
        "lastName": last_name,
        "email": f"{first_name.lower()}.{last_name.lower()}@example.com",
        "segment": random.choice(SEGMENTS),
    }


def random_line_item(order_id: str, index: int) -> dict:
    sku, product_name, unit_price = random.choice(PRODUCTS)
    quantity = random.randint(1, 5)
    line_total = unit_price * quantity
    return {
        "lineItemId": f"{order_id}-L{index}",
        "sku": sku,
        "productName": product_name,
        "quantity": quantity,
        "unitPrice": money(unit_price),
        "lineTotal": money(line_total),
    }


def build_sales_order() -> dict:
    order_id = f"SO-{uuid.uuid4().hex[:12].upper()}"
    line_items = [random_line_item(order_id, index) for index in range(1, random.randint(2, 5))]
    order_total = sum(Decimal(item["lineTotal"]) for item in line_items)
    customer = random_customer()
    return {
        "orderId": order_id,
        "orderTimestamp": datetime.now(timezone.utc).isoformat(),
        "currency": "USD",
        "orderTotal": money(order_total),
        "customer": customer,
        "lineItems": line_items,
    }


def main() -> None:
    bootstrap_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9094").split(",")
    topic = os.getenv("RAW_TOPIC", "raw_sales_orders")
    interval_ms = int(os.getenv("PRODUCER_INTERVAL_MS", "2000"))

    producer = KafkaProducer(
        bootstrap_servers=bootstrap_servers,
        value_serializer=lambda payload: json.dumps(payload).encode("utf-8"),
        linger_ms=50,
        acks="all",
    )

    while True:
        order = build_sales_order()
        producer.send(topic, key=order["orderId"].encode("utf-8"), value=order)
        producer.flush()
        print(f"published order {order['orderId']} for customer {order['customer']['customerId']}", flush=True)
        time.sleep(interval_ms / 1000)


if __name__ == "__main__":
    main()
