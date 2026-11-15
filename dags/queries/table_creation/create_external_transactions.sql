create table if not exists bronze.external_transactions (
    id uuid primary key default gen_random_uuid(),
    transaction_type varchar(255) not null,
    tag varchar(511) not null,
    amount float not null,
    account varchar(255) not null,
    calendar_date date not null,
    subcategory varchar(255) not null,
    currency varchar(255) not null,
    count_to_balance boolean not null
);
