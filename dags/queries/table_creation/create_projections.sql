create table bronze.projections (
    id serial primary key,
    calendar_date date not null,
    simulation_set integer not null,
    transaction_type varchar(255) not null,
    level_2 varchar(255) not null,
    amount float not null
);
