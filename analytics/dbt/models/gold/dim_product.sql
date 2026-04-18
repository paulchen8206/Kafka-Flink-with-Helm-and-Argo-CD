with product_events as (
  select *
  from {{ ref('stg_sales_order_line_item') }}
),
aggregated as (
  select
    sku as product_id,
    max(product_name) as product_name,
    max(currency) as currency,
    min(order_timestamp) as first_seen_at,
    max(order_timestamp) as last_seen_at,
    count(distinct order_id) as orders_count,
    sum(quantity)::bigint as units_sold,
    avg(unit_price)::numeric(18, 2) as avg_unit_price
  from product_events
  where sku is not null
  group by sku
)
select
  product_id,
  product_name,
  currency,
  first_seen_at,
  last_seen_at,
  orders_count,
  units_sold,
  avg_unit_price
from aggregated
