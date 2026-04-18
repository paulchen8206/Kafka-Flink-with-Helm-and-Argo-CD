import json
import os
from typing import Any

from kafka import KafkaConsumer, KafkaProducer


TOPIC_MAP = {
    "mdm_mysql.mdm.customer360": "mdm_customer",
    "mdm_mysql.mdm.product_master": "mdm_product",
}


def decode_json(raw: bytes | None) -> Any:
    if raw is None:
        return None
    return json.loads(raw.decode("utf-8"))


def build_payload(topic: str, value: dict[str, Any]) -> dict[str, Any] | None:
    # Debezium JSON converter may wrap event data in {"schema":..., "payload":...}.
    if "payload" in value and isinstance(value.get("payload"), dict):
        value = value["payload"]

    op = value.get("op")
    if op == "d":
        row = value.get("before")
    else:
        row = value.get("after")

    if row is None:
        return None

    return {
        "entity": "customer" if topic.endswith("customer360") else "product",
        "operation": op,
        "sourceTsMs": value.get("ts_ms"),
        "data": row,
    }


def main() -> None:
    bootstrap_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092").split(",")
    consumer_group = os.getenv("MDM_CDC_GROUP_ID", "mdm-cdc-publisher")

    consumer = KafkaConsumer(
        *TOPIC_MAP.keys(),
        bootstrap_servers=bootstrap_servers,
        group_id=consumer_group,
        auto_offset_reset=os.getenv("CDC_CONSUMER_OFFSET_RESET", "earliest"),
        enable_auto_commit=True,
        value_deserializer=decode_json,
        key_deserializer=lambda k: k.decode("utf-8") if k else None,
    )

    producer = KafkaProducer(
        bootstrap_servers=bootstrap_servers,
        value_serializer=lambda payload: json.dumps(payload).encode("utf-8"),
        key_serializer=lambda key: key.encode("utf-8") if key else None,
        acks="all",
        linger_ms=20,
    )

    print("mdm cdc producer started", flush=True)

    for msg in consumer:
        if msg.value is None:
            continue

        target_topic = TOPIC_MAP.get(msg.topic)
        if target_topic is None:
            continue

        payload = build_payload(msg.topic, msg.value)
        if payload is None:
            continue

        key = str(msg.key) if msg.key else None
        producer.send(target_topic, key=key, value=payload)
        producer.flush()
        print(f"forwarded cdc event from {msg.topic} to {target_topic}", flush=True)


if __name__ == "__main__":
    main()
