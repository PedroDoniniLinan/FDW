create table bronze.exchanges (
    id serial primary key,
    ticker varchar(255) not null,
    account varchar(255) not null,
    calendar_date date not null,
    price float not null,
    units float not null,
    tax float not null,
    exchange_type varchar(255) not null,
    currency varchar(255) not null,
    tax_currency varchar(255) not null,
    count_to_balance boolean not null
);
