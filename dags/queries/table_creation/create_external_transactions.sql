create table if not exists bronze.external_transactions (
    id serial primary key,
    transaction_type varchar(255) not null,
    tag varchar(511) not null,
    amount float not null,
    account varchar(255) not null,
    calendar_date date not null,
    subcategory varchar(255) not null,
    currency varchar(255) not null,
    count_to_balance boolean not null
);
