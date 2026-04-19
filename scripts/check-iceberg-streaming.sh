#!/usr/bin/env sh

set -eu

TRINO_URL="${TRINO_URL:-http://localhost:8086}"
SMOKE_MAX_ATTEMPTS="${SMOKE_MAX_ATTEMPTS:-20}"
SMOKE_SLEEP_SECONDS="${SMOKE_SLEEP_SECONDS:-3}"

curl -fsS "$TRINO_URL/v1/info" >/dev/null

query_count() {
  table_name="$1"
  python3 scripts/trino_query.py \
    --server "$TRINO_URL" \
    --output json \
    --sql "SELECT count(*) AS row_count FROM lakehouse.streaming.${table_name}" \
  | python3 -c 'import json,sys; payload=json.load(sys.stdin); print(payload["data"][0][0] if payload.get("data") else 0)'
}

attempt=1
while [ "$attempt" -le "$SMOKE_MAX_ATTEMPTS" ]; do
  sales_order_count="$(query_count sales_order)"
  sales_order_line_item_count="$(query_count sales_order_line_item)"
  customer_sales_count="$(query_count customer_sales)"

  echo "attempt ${attempt}/${SMOKE_MAX_ATTEMPTS}: sales_order=${sales_order_count} sales_order_line_item=${sales_order_line_item_count} customer_sales=${customer_sales_count}"

  if [ "$sales_order_count" -gt 0 ] && [ "$sales_order_line_item_count" -gt 0 ] && [ "$customer_sales_count" -gt 0 ]; then
    echo "Iceberg streaming smoke test passed."
    exit 0
  fi

  attempt=$((attempt + 1))
  sleep "$SMOKE_SLEEP_SECONDS"
done

echo "Iceberg streaming smoke test failed: one or more tables remained empty." >&2
exit 1