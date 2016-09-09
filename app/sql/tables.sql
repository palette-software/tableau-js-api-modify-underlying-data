drop table if exists sales_by_month;
create table if not exists sales_by_month (
  id serial not null primary key,
  system_name text,
  port_location text,

  product_name text,

  month_start date,

  quantity numeric(10,0),
  unit_price numeric(10,2)

);
