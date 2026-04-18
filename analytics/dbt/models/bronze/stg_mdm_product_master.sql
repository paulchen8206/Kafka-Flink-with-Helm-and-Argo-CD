select
  product_id,
  product_name,
  currency,
  first_seen_at,
  last_seen_at,
  orders_count::bigint as orders_count,
  units_sold::bigint as units_sold,
  avg_unit_price::numeric(18,2) as avg_unit_price,
  updated_at
from landing.mdm_product_master
