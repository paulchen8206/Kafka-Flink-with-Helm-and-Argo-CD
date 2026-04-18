#!/usr/bin/env bash

set -euo pipefail

TOPICS=(
  raw_sales_orders
  sales_order
  sales_order_line_item
  customer_sales
  mdm_customer
  mdm_product
)
MESSAGE_COUNT="${MESSAGE_COUNT:-1}"

for topic in "${TOPICS[@]}"; do
  echo "===== ${topic} ====="
  ./scripts/consume-topic.sh "${topic}" "${MESSAGE_COUNT}"
  echo
done
