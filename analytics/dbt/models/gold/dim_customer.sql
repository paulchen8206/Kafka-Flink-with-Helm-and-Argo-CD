with customer_projection as (
  select *
  from {{ ref('stg_customer_sales') }}
),
order_activity as (
  select
    customer_id,
    min(order_timestamp) as first_order_timestamp,
    max(order_timestamp) as last_order_timestamp,
    count(distinct order_id) as observed_order_count
  from {{ ref('stg_sales_order') }}
  group by customer_id
)
select
  c.customer_id,
  c.customer_name,
  c.customer_email,
  c.customer_segment,
  c.currency,
  a.first_order_timestamp,
  a.last_order_timestamp,
  coalesce(a.observed_order_count, 0) as observed_order_count,
  c.order_count as projected_order_count,
  c.total_spent as projected_total_spent,
  c.updated_at as projection_updated_at
from customer_projection c
left join order_activity a
  on c.customer_id = a.customer_id
