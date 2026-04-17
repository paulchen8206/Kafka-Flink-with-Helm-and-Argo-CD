#!/usr/bin/env bash

set -euo pipefail

TOPIC="${1:-}"
MESSAGE_COUNT="${2:-5}"
BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVERS:-kafka:9092}"
TIMEOUT_MS="${TIMEOUT_MS:-15000}"

if [[ -z "${TOPIC}" ]]; then
  echo "usage: ./scripts/consume-topic.sh <topic> [message-count]" >&2
  exit 1
fi

docker compose exec -T kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server "${BOOTSTRAP_SERVER}" \
  --topic "${TOPIC}" \
  --from-beginning \
  --timeout-ms "${TIMEOUT_MS}" \
  --max-messages "${MESSAGE_COUNT}"
