with calendar_source as (
  select cast(order_timestamp as date) as date_day
  from {{ ref('stg_sales_order') }}

  union

  select cast(order_timestamp as date) as date_day
  from {{ ref('stg_sales_order_line_item') }}
),
dates as (
  select distinct date_day
  from calendar_source
  where date_day is not null
)
select
  cast(to_char(date_day, 'YYYYMMDD') as int) as date_key,
  date_day,
  extract(year from date_day)::int as year,
  extract(quarter from date_day)::int as quarter,
  extract(month from date_day)::int as month,
  trim(to_char(date_day, 'Month')) as month_name,
  extract(week from date_day)::int as week_of_year,
  extract(day from date_day)::int as day_of_month,
  extract(isodow from date_day)::int as day_of_week_iso,
  trim(to_char(date_day, 'Day')) as day_name,
  case
    when extract(isodow from date_day) in (6, 7) then true
    else false
  end as is_weekend
from dates
