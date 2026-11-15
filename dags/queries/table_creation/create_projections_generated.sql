create table if not exists bronze.projections_generated (
    id uuid primary key default gen_random_uuid(),
    calendar_date date not null,
    simulation_set bigint not null,
    transaction_type varchar(255) not null,
    budget_level varchar(255) not null,
    level_2 varchar(255) not null,
    amount float not null
);
