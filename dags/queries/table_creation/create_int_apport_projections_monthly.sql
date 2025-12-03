create table if not exists silver.int_apport_projections_monthly (
    calendar_date date not null,
    is_end_of_period varchar(255) not null,
    simulation_set integer not null,
    apport float not null
);

