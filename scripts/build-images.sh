#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-realtime-dev}"
PRODUCER_IMAGE="${PRODUCER_IMAGE:-realtime-sales-producer:0.1.0}"
PROCESSOR_IMAGE="${PROCESSOR_IMAGE:-realtime-sales-processor:0.1.0}"

docker build -t "${PRODUCER_IMAGE}" ./producer
docker build -t "${PROCESSOR_IMAGE}" ./processor

kind load docker-image --name "${CLUSTER_NAME}" "${PRODUCER_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${PROCESSOR_IMAGE}"

echo "Images loaded into kind cluster '${CLUSTER_NAME}'"