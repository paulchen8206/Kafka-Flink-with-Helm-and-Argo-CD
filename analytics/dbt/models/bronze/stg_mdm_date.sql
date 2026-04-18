select
  date_key::int as date_key,
  full_date as date_day,
  day_of_month::int as day_of_month,
  day_of_week::int as day_of_week_iso,
  day_name,
  week_of_year::int as week_of_year,
  month_of_year::int as month,
  month_name,
  quarter_of_year::int as quarter,
  year_number::int as year,
  is_weekend,
  created_at,
  updated_at
from landing.mdm_date
