select
  date_key,
  date_day,
  year,
  quarter,
  month,
  month_name,
  week_of_year,
  day_of_month,
  day_of_week_iso,
  day_name,
  is_weekend,
  created_at,
  updated_at
from {{ ref('stg_mdm_date') }}
