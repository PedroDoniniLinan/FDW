create table if not exists silver.int_fiat_balances_daily (
    account varchar(255) not null,
    original_currency varchar(255) not null,
    currency varchar(255) not null,
    calendar_date date not null,
    is_end_of_period varchar(255) not null,
    original_balance float,
    price float,
    balance float
);












