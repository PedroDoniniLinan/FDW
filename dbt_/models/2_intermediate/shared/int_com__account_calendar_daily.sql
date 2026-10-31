{{ config(
    materialized='table',
    tags=['refactored', 'balance_validation', 'main']
) }}

with

raw_daily_grid as (
    select
        calendar_date,
        is_end_of_period
    from {{ ref("int_com__calendar_daily") }}
),

raw_transactions as (
    select account, asset
    from {{ ref("fct_trx__cashflow_daily") }}
),

transaction_assets as (
    select distinct
        account,
        asset
    from raw_transactions
),

grid_accounts as (
    select
        t.account,
        t.asset,
        g.calendar_date,
        g.is_end_of_period
    from raw_daily_grid as g
    cross join transaction_assets as t
),

final as (
    select account, asset, calendar_date, is_end_of_period
    from grid_accounts
)

select * from final
