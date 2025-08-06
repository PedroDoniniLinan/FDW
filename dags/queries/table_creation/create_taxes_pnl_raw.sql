create table silver.taxes_pnl_raw (
    ticker varchar(255) not null,
    currency varchar(255) not null,
    calendar_date date not null,
    net_amount float not null,
    avg_price float not null,
    sale_price float not null,
    applied_value float not null,
    sale_value float not null,
    pnl float not null
);
