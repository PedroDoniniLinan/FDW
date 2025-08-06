create table gold.allocation_simulations (
    id serial primary key,
    set integer not null,
    method varchar(255) not null,
    start_date date not null,
    calendar_date date not null,
    balance float,
    capital_gain float
);