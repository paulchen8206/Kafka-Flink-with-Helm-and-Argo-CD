# ── Variables ─────────────────────────────────────────────────────────────────
CLUSTER_NAME    ?= realtime-dev
PRODUCER_IMAGE  ?= realtime-sales-producer:0.1.0
PROCESSOR_IMAGE ?= realtime-sales-processor:0.1.0
CONNECT_IMAGE   ?= realtime-sales-connect:0.1.0
DBT_IMAGE       ?= realtime-sales-dbt:0.1.0
AIRFLOW_IMAGE   ?= realtime-sales-airflow:0.1.0
MDM_WRITER_IMAGE ?= realtime-sales-mdm-writer:0.1.0
MDM_CDC_PRODUCER_IMAGE ?= realtime-sales-mdm-cdc-producer:0.1.0
MDM_PYSPARK_SYNC_IMAGE ?= realtime-sales-mdm-pyspark-sync:0.1.0
ICEBERG_WRITER_IMAGE ?= realtime-sales-iceberg-writer:0.1.0
ENV             ?= dev
KAFKA_BOOTSTRAP ?= kafka:9092
TOPIC           ?=
MESSAGE_COUNT   ?= 5
TRINO_URL       ?= http://localhost:8086
SQL_FILE        ?=

# ── Phony targets ─────────────────────────────────────────────────────────────
.PHONY: help validate \
        build \
	routine-a up down topics-create topics-list topics-check consume \
	routine-a-ops \
	lakehouse-up lakehouse-down jdbc-metastore-migrate airflow-up airflow-logs airflow-trigger-dbt-dag airflow-dbt-reboot \
	kafka-ui-up dbt-stop ops-status mdm-up mdm-topics-check \
	dbt-run verify-warehouse verify-dbt-relations trino-smoke trino-query trino-shell trino-seed-demo trino-bootstrap-lakehouse trino-rebuild-lakehouse trino-sync-lakehouse trino-sample-queries iceberg-streaming-smoke iceberg-streaming-smoke-dev trino-smoke-dev \
		routine-b routine-b-ops routine-b-down routine-b-argocd ops-status-dev mdm-topics-check-dev airflow-dbt-check-dev docker-build kind-load images kind-bootstrap argocd-apply \
          helm-deps helm-lint helm-render-dev helm-render-qa helm-render-prd helm-render \
	  helm-reboot-dev helm-health-dev

# ── Help ──────────────────────────────────────────────────────────────────────
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
	  awk 'BEGIN{FS=":.*##"} {printf "  %-22s %s\n", $$1, $$2}'

# ── Shared ────────────────────────────────────────────────────────────────────
build: ## [shared]  Build the processor JAR (tests skipped)
	cd processor && mvn -DskipTests package

validate: build helm-lint helm-render ## [shared]  Build + lint + render all envs + compose parse
	docker compose config > /dev/null
	@echo "All validations passed."

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Routine A – Docker Compose  (fast local application loop)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
routine-a: up topics-create ## [A]  Full Routine A bootstrap: start stack + create topics

routine-a-ops: ## [A]  Unified ops runbook: kafka-ui up, dbt off, MDM checks, airflow+dbt reboot, status
	$(MAKE) kafka-ui-up
	$(MAKE) dbt-stop
	$(MAKE) mdm-up
	$(MAKE) mdm-topics-check
	$(MAKE) airflow-dbt-reboot
	$(MAKE) ops-status

up: ## [A]  Start local docker-compose stack
	./scripts/compose-up.sh -d

down: ## [A]  Stop local docker-compose stack
	docker compose down

topics-create: ## [A]  Create Kafka topics (runs topic-init service)  [scripts/create-topics.sh]
	docker compose run --rm topic-init

topics-list: ## [A]  List Kafka topics  [scripts/list-topics.sh]
	KAFKA_BOOTSTRAP_SERVERS="$(KAFKA_BOOTSTRAP)" ./scripts/list-topics.sh

topics-check: ## [A]  Sample messages from every pipeline topic  [scripts/check-pipeline-topics.sh]
	MESSAGE_COUNT="$(MESSAGE_COUNT)" ./scripts/check-pipeline-topics.sh

consume: ## [A]  Consume TOPIC (make consume TOPIC=raw_sales_orders)  [scripts/consume-topic.sh]
	@if [ -z "$(TOPIC)" ]; then echo "Usage: make consume TOPIC=<topic-name>" >&2; exit 1; fi
	KAFKA_BOOTSTRAP_SERVERS="$(KAFKA_BOOTSTRAP)" ./scripts/consume-topic.sh "$(TOPIC)" "$(MESSAGE_COUNT)"

lakehouse-up: ## [A]  Start Kafka Connect + MinIO + Postgres + dbt layer
	./scripts/compose-up.sh -d minio minio-init trino postgres connect connect-init iceberg-writer airflow

jdbc-metastore-migrate: ## [A]  Upgrade the Postgres-backed Iceberg JDBC metastore to the V1 schema and restart dependent services
	docker compose exec -T postgres sh -lc 'until pg_isready -U analytics -d analytics >/dev/null 2>&1; do sleep 1; done; psql -U analytics -d analytics -c "ALTER TABLE IF EXISTS iceberg_tables ADD COLUMN IF NOT EXISTS iceberg_type varchar(5);"'
	docker compose restart trino iceberg-writer

lakehouse-down: ## [A]  Stop Kafka Connect + MinIO + Postgres + dbt layer
	docker compose stop airflow iceberg-writer connect-init connect postgres trino minio-init minio

airflow-up: ## [A]  Start Apache Airflow for scheduled dbt runs
	./scripts/compose-up.sh -d --build airflow

airflow-dbt-reboot: ## [A]  Rebuild/restart Airflow, run dbt once, then show airflow/dbt status
	./scripts/compose-up.sh -d --build airflow
	docker compose run --rm dbt
	docker compose ps airflow dbt

kafka-ui-up: ## [A]  Start Kafka UI only (without running dbt)
	docker compose up -d kafka-ui
	docker compose ps kafka-ui dbt

dbt-stop: ## [A]  Ensure dbt is not running
	docker compose stop dbt || true
	docker compose ps dbt

ops-status: ## [A]  Show key runtime status for kafka-ui, airflow, and dbt
	docker compose ps kafka-ui airflow dbt

mdm-up: ## [A]  Start MDM CDC pipeline services
	docker compose up -d mysql-mdm mdm-writer mdm-connect mdm-connect-init mdm-cdc-producer
	docker compose ps mysql-mdm mdm-writer mdm-connect mdm-connect-init mdm-cdc-producer

mdm-topics-check: ## [A]  Check MDM topic availability and consume sample records
	./scripts/list-topics.sh
	./scripts/consume-topic.sh mdm_customer 3 || true
	./scripts/consume-topic.sh mdm_product 3 || true

airflow-logs: ## [A]  Tail Apache Airflow logs
	docker compose logs --tail=200 airflow

airflow-trigger-dbt-dag: ## [A]  Trigger the scheduled dbt Airflow DAG manually
	docker compose exec -T airflow airflow dags trigger dbt_warehouse_schedule

dbt-run: ## [A]  Run dbt bronze, silver, and gold models on Postgres
	docker compose run --rm dbt

verify-warehouse: ## [A]  Show landing, bronze, silver, and gold row counts in Postgres
	docker compose exec -T postgres psql -U analytics -d analytics -c "select count(*) as landing_sales_order from landing.sales_order; select count(*) as landing_sales_order_line_item from landing.sales_order_line_item; select count(*) as landing_customer_sales from landing.customer_sales; select count(*) as bronze_sales_order from bronze.stg_sales_order; select count(*) as bronze_sales_order_line_item from bronze.stg_sales_order_line_item; select count(*) as bronze_customer_sales from bronze.stg_customer_sales; select count(*) as silver_fact_sales_order from silver.fact_sales_order; select count(*) as gold_customer_sales_summary from gold.gold_customer_sales_summary;"

verify-dbt-relations: ## [A]  List dbt-created relations in bronze, silver, and gold
	docker compose exec -T postgres psql -U analytics -d analytics -c "select table_schema, table_name, table_type from information_schema.tables where table_schema in ('bronze', 'silver', 'gold') order by table_schema, table_name;"

trino-smoke: ## [A]  Check local Trino coordinator health
	curl -fsS http://localhost:8086/v1/info

trino-query: ## [A]  Run a SQL file through local Trino (make trino-query SQL_FILE=trino/sql/sample_queries.sql)
	@if [ -z "$(SQL_FILE)" ]; then echo "Usage: make trino-query SQL_FILE=<path-to-sql-file>" >&2; exit 1; fi
	python3 scripts/trino_query.py --server "$(TRINO_URL)" --file "$(SQL_FILE)"

trino-shell: ## [A]  Open a Trino CLI shell or run ad hoc SQL (make trino-shell SQL_FILE=trino/sql/sample_queries.sql)
	@if [ -n "$(SQL_FILE)" ]; then TRINO_SCHEMA=streaming ./scripts/trino-sql.sh "$(SQL_FILE)"; else TRINO_SCHEMA=streaming ./scripts/trino-sql.sh; fi

trino-seed-demo: ## [A]  Create a small demo Iceberg dataset on MinIO through Trino
	python3 scripts/trino_query.py --server "$(TRINO_URL)" --file trino/sql/bootstrap_demo_seed.sql

trino-bootstrap-lakehouse: ## [A]  Materialize Iceberg tables on MinIO from Postgres landing data through Trino
	python3 scripts/trino_query.py --server "$(TRINO_URL)" --file trino/sql/bootstrap_lakehouse.sql

trino-rebuild-lakehouse: ## [A]  Drop and recreate all demo Iceberg tables in one command
	$(MAKE) jdbc-metastore-migrate
	python3 scripts/trino_query.py --server "$(TRINO_URL)" --file trino/sql/bootstrap_demo_seed.sql
	python3 scripts/trino_query.py --server "$(TRINO_URL)" --file trino/sql/bootstrap_lakehouse.sql

trino-sync-lakehouse: ## [A]  Incrementally sync Postgres landing data into Iceberg tables on MinIO
	python3 scripts/trino_query.py --server "$(TRINO_URL)" --file trino/sql/incremental_sync_lakehouse.sql

trino-sample-queries: ## [A]  Run sample Trino SQL against the lakehouse catalogs
	python3 scripts/trino_query.py --server "$(TRINO_URL)" --file trino/sql/sample_queries.sql

iceberg-streaming-smoke: ## [A]  Verify Kafka events reached lakehouse.streaming Iceberg tables
	TRINO_URL="$(TRINO_URL)" ./scripts/check-iceberg-streaming.sh

iceberg-streaming-smoke-dev: ## [B]  Verify Iceberg streaming tables in the dev cluster through a Trino port-forward
	K8S_NAMESPACE=realtime-dev TRINO_SERVICE=realtime-dev-realtime-app-trino LOCAL_TRINO_PORT=8086 ./scripts/check-iceberg-streaming-k8s.sh

trino-smoke-dev: ## [B]  Check Trino pod health in the dev namespace
	kubectl -n realtime-dev wait --for=condition=Ready pod -l app.kubernetes.io/component=trino --timeout=300s
	kubectl -n realtime-dev get pods -l app.kubernetes.io/component=trino
	kubectl -n realtime-dev logs deploy/realtime-dev-realtime-app-trino --tail=50 || true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Routine B – kind + Helm + Argo CD  (GitOps local cluster loop)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
routine-b: kind-bootstrap images helm-reboot-dev ## [B]  Full Routine B bootstrap: cluster + images + local Helm deploy (Docker-like flow)

routine-b-ops: ## [B]  Unified ops runbook parity with routine-a-ops for the dev cluster
	$(MAKE) ops-status-dev
	$(MAKE) mdm-topics-check-dev
	$(MAKE) airflow-dbt-check-dev
	$(MAKE) trino-smoke-dev
	$(MAKE) iceberg-streaming-smoke-dev

routine-b-down: ## [B]  Stop Routine B workloads (remove Argo CD app and Helm release)
	kubectl -n argocd delete application realtime-dev --ignore-not-found=true || true
	helm uninstall realtime-dev -n realtime-dev || true

routine-b-argocd: kind-bootstrap images argocd-apply ## [B]  Full Routine B bootstrap: cluster + images + ArgoCD app

ops-status-dev: ## [B]  Show Argo app, pod, and job status snapshot in dev namespace
	kubectl -n argocd get application realtime-dev || true
	kubectl -n realtime-dev get pods
	kubectl -n realtime-dev get jobs

mdm-topics-check-dev: ## [B]  Validate mdm_customer and mdm_product topic flow in the dev cluster
	kubectl -n realtime-dev exec realtime-dev-kafka-controller-0 -- /opt/bitnami/kafka/bin/kafka-console-consumer.sh --bootstrap-server realtime-dev-kafka:9092 --topic mdm_customer --partition 0 --offset 0 --max-messages 1 --timeout-ms 15000
	kubectl -n realtime-dev exec realtime-dev-kafka-controller-0 -- /opt/bitnami/kafka/bin/kafka-console-consumer.sh --bootstrap-server realtime-dev-kafka:9092 --topic mdm_product --partition 0 --offset 0 --max-messages 1 --timeout-ms 15000

airflow-dbt-check-dev: ## [B]  Validate Airflow deployment and dbt bootstrap job status/logs in dev
	kubectl -n realtime-dev get pods -l app.kubernetes.io/component=airflow
	kubectl -n realtime-dev get jobs | grep realtime-dev-realtime-app-dbt || true
	kubectl -n realtime-dev logs job/realtime-dev-realtime-app-dbt --tail=60 || true

docker-build: ## [B]  Build producer + processor Docker images
	docker build -t "$(PRODUCER_IMAGE)"  ./producer
	docker build -t "$(PROCESSOR_IMAGE)" ./processor
	docker build -t "$(CONNECT_IMAGE)" ./connect
	docker build -t "$(DBT_IMAGE)" ./analytics/dbt
	docker build -t "$(AIRFLOW_IMAGE)" ./airflow
	docker build -t "$(MDM_WRITER_IMAGE)" ./mdm-writer
	docker build -t "$(MDM_CDC_PRODUCER_IMAGE)" ./mdm-cdc-producer
	docker build -t "$(MDM_PYSPARK_SYNC_IMAGE)" ./mdm-pyspark-sync
	docker build -t "$(ICEBERG_WRITER_IMAGE)" ./iceberg-writer

kind-load: ## [B]  Load images into the kind cluster
	kind load docker-image --name "$(CLUSTER_NAME)" "$(PRODUCER_IMAGE)"
	kind load docker-image --name "$(CLUSTER_NAME)" "$(PROCESSOR_IMAGE)"
	kind load docker-image --name "$(CLUSTER_NAME)" "$(CONNECT_IMAGE)"
	kind load docker-image --name "$(CLUSTER_NAME)" "$(DBT_IMAGE)"
	kind load docker-image --name "$(CLUSTER_NAME)" "$(AIRFLOW_IMAGE)"
	kind load docker-image --name "$(CLUSTER_NAME)" "$(MDM_WRITER_IMAGE)"
	kind load docker-image --name "$(CLUSTER_NAME)" "$(MDM_CDC_PRODUCER_IMAGE)"
	kind load docker-image --name "$(CLUSTER_NAME)" "$(MDM_PYSPARK_SYNC_IMAGE)"
	kind load docker-image --name "$(CLUSTER_NAME)" "$(ICEBERG_WRITER_IMAGE)"

images: docker-build kind-load ## [B]  Build images and load into kind  [scripts/build-images.sh]

kind-bootstrap: ## [B]  Create kind cluster and install Argo CD  [scripts/bootstrap-kind.sh]
	kind create cluster --name "$(CLUSTER_NAME)" --wait 120s
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

argocd-apply: ## [B]  Apply the Argo CD Application manifest for ENV (default: dev)
	kubectl apply -f argocd/$(ENV).yaml

helm-deps: ## [B]  Download / update Helm chart dependencies
	helm dependency build charts/realtime-app

helm-lint: helm-deps ## [B]  Lint the Helm chart
	helm lint charts/realtime-app

helm-render-dev: helm-deps ## [B]  Render Helm templates for dev
	helm template realtime-dev charts/realtime-app -f environments/dev/values.yaml

helm-render-qa: helm-deps ## [B]  Render Helm templates for qa
	helm template realtime-qa  charts/realtime-app -f environments/qa/values.yaml

helm-render-prd: helm-deps ## [B]  Render Helm templates for prd
	helm template realtime-prd charts/realtime-app -f environments/prd/values.yaml

helm-render: helm-render-dev helm-render-qa helm-render-prd ## [B]  Render templates for all environments

helm-reboot-dev: ## [B]  Reboot dev namespace via local Helm chart and values
	helm upgrade --install realtime-dev charts/realtime-app -n realtime-dev --create-namespace -f environments/dev/values.yaml
	$(MAKE) helm-health-dev

helm-health-dev: ## [B]  Show dev Helm workload health snapshot (pods, jobs, dbt bootstrap logs)
	kubectl -n realtime-dev get pods
	kubectl -n realtime-dev get jobs
	kubectl -n realtime-dev logs job/realtime-dev-realtime-app-dbt --tail=60 || true
