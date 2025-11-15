create table if not exists gold.balance_discrepancies (
    account varchar(255) not null,
    currency varchar(255) not null,
    calendar_date date not null,
    balance_actual float,
    balance_calculated float,
    delta float
);

