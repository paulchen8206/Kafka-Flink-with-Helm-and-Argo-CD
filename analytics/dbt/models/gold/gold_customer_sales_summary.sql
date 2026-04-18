with sales as (
  select * from {{ ref('stg_customer_sales') }}
),
dim_customer as (
  select * from {{ ref('dim_mdm_customer') }}
),
fact_sales_order as (
  select * from {{ ref('fact_sales_order') }}
),
fact_rollup as (
  select
    customer_id,
    sum(line_total) as recomputed_total_from_line_items,
    count(*) as total_line_items,
    count(distinct product_id) as distinct_products_purchased,
    count(distinct order_id) as observed_orders,
    max(order_timestamp) as last_order_timestamp,
    max(date_key) as last_order_date_key,
    max(year) as last_order_year,
    max(quarter) as last_order_quarter,
    max(month) as last_order_month,
    max(month_name) as last_order_month_name,
    bool_or(coalesce(is_weekend, false)) as has_weekend_orders,
    max(order_timestamp) as last_line_item_timestamp
  from fact_sales_order
  group by customer_id
)
select
  s.customer_id,
  coalesce(c.customer_name, s.customer_name) as customer_name,
  coalesce(c.customer_email, s.customer_email) as customer_email,
  coalesce(c.customer_segment, s.customer_segment) as customer_segment,
  coalesce(c.currency, s.currency) as currency,
  coalesce(c.projected_order_count, s.order_count) as latest_order_count,
  coalesce(c.projected_total_spent, s.total_spent) as latest_total_spent,
  coalesce(f.recomputed_total_from_line_items, 0) as recomputed_total_from_line_items,
  coalesce(f.total_line_items, 0) as total_line_items,
  coalesce(f.distinct_products_purchased, 0) as distinct_products_purchased,
  coalesce(f.observed_orders, 0) as observed_orders,
  f.last_order_timestamp,
  f.last_order_date_key,
  f.last_order_year,
  f.last_order_quarter,
  f.last_order_month,
  f.last_order_month_name,
  coalesce(f.has_weekend_orders, false) as has_weekend_orders,
  coalesce(c.projection_updated_at, s.updated_at) as projection_updated_at,
  f.last_line_item_timestamp,
  c.updated_at as mdm_customer_updated_at
from sales s
left join dim_customer c
  on s.customer_id = c.customer_id
left join fact_rollup f
  on s.customer_id = f.customer_id
