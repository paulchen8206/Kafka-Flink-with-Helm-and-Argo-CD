#!/usr/bin/env sh

set -eu

CONNECT_URL="${CONNECT_URL:-http://mdm-connect:8083}"

until curl -sf "${CONNECT_URL}/connectors" >/dev/null; do
  echo "Waiting for MDM Debezium Connect REST API..."
  sleep 3
done

if curl -sf "${CONNECT_URL}/connectors/debezium-mysql-mdm" >/dev/null; then
  curl -sf -X PUT \
    -H "Content-Type: application/json" \
    --data @/connector-configs/debezium-mysql-mdm.json \
    "${CONNECT_URL}/connectors/debezium-mysql-mdm/config" >/dev/null
else
  curl -sf -X POST \
    -H "Content-Type: application/json" \
    --data "{\"name\":\"debezium-mysql-mdm\",\"config\":$(cat /connector-configs/debezium-mysql-mdm.json)}" \
    "${CONNECT_URL}/connectors" >/dev/null
fi

echo "Debezium MDM connector is registered."
