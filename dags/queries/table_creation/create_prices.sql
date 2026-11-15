create table if not exists bronze.prices (
    id uuid primary key default gen_random_uuid(),
    ticker varchar(255) not null,
    currency varchar(255) not null,
    calendar_date date not null,
    price float not null
);
