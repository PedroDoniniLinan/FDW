create table bronze.prices (
    id serial primary key,
    ticker varchar(255) not null,
    currency varchar(255) not null,
    calendar_date date not null,
    price float not null
);
