create table silver.balance_projections (
    calendar_date date not null,
    is_end_of_period varchar(255) not null,
    simulation_set integer not null,
    interest float not null,
    apport float not null,
    balance float not null
);
