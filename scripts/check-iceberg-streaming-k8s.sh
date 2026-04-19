#!/usr/bin/env sh

set -eu

K8S_NAMESPACE="${K8S_NAMESPACE:-realtime-dev}"
TRINO_SERVICE="${TRINO_SERVICE:-realtime-dev-realtime-app-trino}"
LOCAL_TRINO_PORT="${LOCAL_TRINO_PORT:-8086}"
TRINO_REMOTE_PORT="${TRINO_REMOTE_PORT:-8080}"
TRINO_DEPLOYMENT="${TRINO_DEPLOYMENT:-$TRINO_SERVICE}"

port_forward_log="$(mktemp)"
cleanup() {
  if [ -n "${port_forward_pid:-}" ]; then
    kill "$port_forward_pid" >/dev/null 2>&1 || true
    wait "$port_forward_pid" 2>/dev/null || true
  fi
  rm -f "$port_forward_log"
}
trap cleanup EXIT INT TERM

kubectl -n "$K8S_NAMESPACE" rollout status "deployment/$TRINO_DEPLOYMENT" --timeout=300s >/dev/null
kubectl -n "$K8S_NAMESPACE" port-forward "deployment/$TRINO_DEPLOYMENT" "$LOCAL_TRINO_PORT:$TRINO_REMOTE_PORT" >"$port_forward_log" 2>&1 &
port_forward_pid=$!

attempt=1
while [ "$attempt" -le 20 ]; do
  if curl -fsS "http://localhost:${LOCAL_TRINO_PORT}/v1/info" >/dev/null 2>&1; then
    TRINO_URL="http://localhost:${LOCAL_TRINO_PORT}" ./scripts/check-iceberg-streaming.sh
    exit 0
  fi
  sleep 1
  attempt=$((attempt + 1))
done

cat "$port_forward_log" >&2
echo "Failed to establish Trino port-forward for Kubernetes smoke test." >&2
exit 1