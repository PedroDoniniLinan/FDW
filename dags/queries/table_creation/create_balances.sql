create table bronze.balances (
    id serial primary key,
    account varchar(255) not null,
    calendar_date date not null,
    currency varchar(255) not null,
    amount float
);