CREATE SCHEMA IF NOT EXISTS lakehouse.demo
WITH (location = 's3://warehouse/iceberg/demo');

DROP TABLE IF EXISTS lakehouse.demo.sample_orders;
CREATE TABLE lakehouse.demo.sample_orders (
  order_id VARCHAR,
  customer_id VARCHAR,
  customer_name VARCHAR,
  currency VARCHAR,
  order_total DOUBLE,
  order_ts TIMESTAMP
)
WITH (
  format = 'PARQUET',
  location = 's3://warehouse/iceberg/demo/sample_orders'
);

INSERT INTO lakehouse.demo.sample_orders (order_id, customer_id, customer_name, currency, order_total, order_ts)
VALUES
  ('ORD-DEMO-001', 'CUST-DEMO-001', 'Ada Lovelace', 'USD', 120.50, TIMESTAMP '2026-04-18 09:00:00'),
  ('ORD-DEMO-002', 'CUST-DEMO-002', 'Grace Hopper', 'USD', 310.25, TIMESTAMP '2026-04-18 10:30:00'),
  ('ORD-DEMO-003', 'CUST-DEMO-001', 'Ada Lovelace', 'USD', 89.99, TIMESTAMP '2026-04-18 11:15:00');
