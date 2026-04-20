#!/usr/bin/env sh

set -eu

if [ "$#" -eq 0 ]; then
  set -- -d --build
fi

docker compose up "$@"

running_services="$(docker compose ps --services --status running)"

if ! printf '%s\n' "$running_services" | grep -qx postgres; then
  echo "Skipping JDBC metastore migration because postgres is not running."
  exit 0
fi

docker compose exec -T postgres sh -lc 'until pg_isready -U analytics -d analytics >/dev/null 2>&1; do sleep 1; done; psql -U analytics -d analytics -c "ALTER TABLE IF EXISTS iceberg_tables ADD COLUMN IF NOT EXISTS iceberg_type varchar(5);"'

running_services="$(docker compose ps --services --status running)"

services_to_restart=""

if printf '%s\n' "$running_services" | grep -qx trino; then
  services_to_restart="$services_to_restart trino"
fi

if printf '%s\n' "$running_services" | grep -qx iceberg-writer; then
  services_to_restart="$services_to_restart iceberg-writer"
fi

if [ -n "$services_to_restart" ]; then
  docker compose restart $services_to_restart
fi