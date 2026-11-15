create table if not exists bronze.balances (
    id uuid primary key default gen_random_uuid(),
    account varchar(255) not null,
    calendar_date date not null,
    currency varchar(255) not null,
    amount float
);
