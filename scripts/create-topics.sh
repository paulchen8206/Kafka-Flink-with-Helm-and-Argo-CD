#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVERS:-kafka:9092}"
TOPICS=(raw_sales_orders sales_order sales_order_line_item customer_sales)
KAFKA_TOPICS_BIN="${KAFKA_TOPICS_BIN:-/opt/kafka/bin/kafka-topics.sh}"

echo "Waiting for Kafka on ${BOOTSTRAP_SERVER}"
until "${KAFKA_TOPICS_BIN}" --bootstrap-server "${BOOTSTRAP_SERVER}" --list >/dev/null 2>&1; do
  sleep 2
done

for topic in "${TOPICS[@]}"; do
  "${KAFKA_TOPICS_BIN}" \
    --bootstrap-server "${BOOTSTRAP_SERVER}" \
    --create \
    --if-not-exists \
    --topic "${topic}" \
    --replication-factor 1 \
    --partitions 3
done

echo "Kafka topics are ready"

