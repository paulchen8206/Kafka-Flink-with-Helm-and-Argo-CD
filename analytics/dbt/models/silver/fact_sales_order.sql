with orders as (
  select * from {{ ref('stg_sales_order') }}
),
line_items as (
  select * from {{ ref('stg_sales_order_line_item') }}
),
dim_customer as (
  select * from {{ ref('dim_mdm_customer') }}
),
dim_product as (
  select * from {{ ref('dim_mdm_product') }}
),
dim_date as (
  select * from {{ ref('dim_mdm_date') }}
),
joined as (
  select
    li.order_id,
    li.line_item_id,
    li.order_timestamp,
    cast(li.order_timestamp as date) as order_date,
    li.customer_id,
    li.sku as product_id,
    li.quantity,
    li.unit_price,
    li.line_total,
    o.order_total,
    o.line_item_count,
    coalesce(li.currency, o.currency) as currency,
    coalesce(dc.customer_name, o.customer_name, li.customer_name) as customer_name,
    dc.customer_email,
    dc.customer_segment,
    coalesce(dp.product_name, li.product_name) as product_name,
    dd.date_key,
    dd.year,
    dd.quarter,
    dd.month,
    dd.month_name,
    dd.day_name,
    dd.is_weekend
  from line_items li
  left join orders o
    on li.order_id = o.order_id
  left join dim_customer dc
    on li.customer_id = dc.customer_id
  left join dim_product dp
    on li.sku = dp.product_id
  left join dim_date dd
    on cast(li.order_timestamp as date) = dd.date_day
)
select
  order_id,
  line_item_id,
  order_timestamp,
  order_date,
  customer_id,
  customer_name,
  customer_email,
  customer_segment,
  product_id,
  product_name,
  date_key,
  year,
  quarter,
  month,
  month_name,
  day_name,
  is_weekend,
  quantity,
  unit_price,
  line_total,
  order_total,
  line_item_count,
  currency
from joined
