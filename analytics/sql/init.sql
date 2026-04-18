create schema if not exists landing;
create schema if not exists bronze;
create schema if not exists silver;
create schema if not exists gold;

create table if not exists landing.sales_order (
	orderid text,
	ordertimestamp timestamptz,
	customerid text,
	customername text,
	customeremail text,
	customersegment text,
	currency text,
	ordertotal numeric,
	lineitemcount integer
);

create table if not exists landing.sales_order_line_item (
	orderid text,
	ordertimestamp timestamptz,
	customerid text,
	customername text,
	lineitemid text,
	sku text,
	productname text,
	quantity integer,
	unitprice numeric,
	linetotal numeric,
	currency text
);

create table if not exists landing.customer_sales (
	customerid text,
	customername text,
	customeremail text,
	customersegment text,
	ordercount bigint,
	totalspent numeric,
	lastorderid text,
	updatedat timestamptz,
	currency text
);

create table if not exists landing.mdm_customer360 (
	customer_id text,
	customer_name text,
	customer_email text,
	customer_segment text,
	currency text,
	first_order_timestamp timestamptz,
	last_order_timestamp timestamptz,
	projected_order_count integer,
	projected_total_spent numeric(18,2),
	projection_updated_at timestamptz,
	updated_at timestamptz
);

create table if not exists landing.mdm_product_master (
	product_id text,
	product_name text,
	currency text,
	first_seen_at timestamptz,
	last_seen_at timestamptz,
	orders_count integer,
	units_sold integer,
	avg_unit_price numeric(18,2),
	updated_at timestamptz
);

create table if not exists landing.mdm_date (
	date_key integer,
	full_date date,
	day_of_month integer,
	day_of_week integer,
	day_name text,
	week_of_year integer,
	month_of_year integer,
	month_name text,
	quarter_of_year integer,
	year_number integer,
	is_weekend boolean,
	created_at timestamptz,
	updated_at timestamptz
);
