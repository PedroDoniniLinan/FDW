{{ config(schema='gold', materialized='table') }}

select
    account,
    account_country,
    account_budget_level,
    currency,
    original_currency,
    level_1,
    level_2,
    level_3,
    source,
    calendar_date,
    is_end_of_period,
    original_balance,
    price,
    balance
from {{ref("int_fiat_balances_daily_star")}}