create table if not exists silver.taxes_avg_price_raw (
    ticker varchar(255) not null,
    currency varchar(255) not null,
    calendar_date date not null,
    avg_price float not null,
    units float not null,
    position float not null
);
