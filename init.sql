-- Create schemas if they don't exist
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

-- Create tables
create table if not exists gold.allocation_simulations (
    id serial primary key,
    set integer not null,
    method varchar(255) not null,
    start_date date not null,
    calendar_date date not null,
    balance float,
    capital_gain float
);

create table if not exists silver.balance_projections (
    calendar_date date not null,
    is_end_of_period varchar(255) not null,
    simulation_set integer not null,
    level_3 varchar(255) not null,
    interest float not null,
    apport float not null,
    balance float not null
);

create table if not exists bronze.balances (
    id serial primary key,
    account varchar(255) not null,
    calendar_date date not null,
    currency varchar(255) not null,
    amount float
);

create table if not exists bronze.exchanges (
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


create table if not exists bronze.prices (
    id serial primary key,
    ticker varchar(255) not null,
    currency varchar(255) not null,
    calendar_date date not null,
    price float not null
);

create table if not exists bronze.projections (
    id serial primary key,
    calendar_date date not null,
    simulation_set integer not null,
    transaction_type varchar(255) not null,
    budget_level varchar(255) not null,
    level_2 varchar(255) not null,
    amount float not null
);

create table if not exists silver.taxes_avg_price_raw (
    ticker varchar(255) not null,
    currency varchar(255) not null,
    calendar_date date not null,
    avg_price float not null,
    units float not null,
    position float not null
);

create table if not exists silver.taxes_pnl_raw (
    ticker varchar(255) not null,
    currency varchar(255) not null,
    calendar_date date not null,
    pnl float not null
);

create table if not exists bronze.transfers (
    id serial primary key,
    source_acc varchar(255) not null,
    destination_acc varchar(255) not null,
    calendar_date date not null,
    amount float not null,
    currency varchar(255) not null,
    count_to_balance boolean not null
);

create table if not exists gold.balance_discrepancies (
    account varchar(255) not null,
    currency varchar(255) not null,
    calendar_date date not null,
    balance_actual float,
    balance_calculated float,
    delta float
);

create table if not exists silver.int_apport_projections_monthly (
    calendar_date date not null,
    is_end_of_period varchar(255) not null,
    simulation_set integer not null,
    apport float not null
);

create table if not exists silver.int_fiat_balances_daily (
    account varchar(255) not null,
    original_currency varchar(255) not null,
    currency varchar(255) not null,
    calendar_date date not null,
    is_end_of_period varchar(255) not null,
    original_balance float,
    price float,
    balance float
);

create table if not exists silver.int_yield_stats (
    level_3 varchar(255) not null,
    avg_pos_yield float,
    avg_neg_yield float,
    pos_year_pct float,
    allocation_pos_yield float,
    allocation_neg_yield float
);