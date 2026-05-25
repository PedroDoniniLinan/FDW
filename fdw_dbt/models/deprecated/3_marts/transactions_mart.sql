{{ config(schema='gold', materialized='table') }}

select
    transaction_id,
    calendar_date,
    tag,
    original_currency,
    currency,
    transaction_type,
    label,
    budget_level,
    level_1,
    level_2,
    level_3,
    source,
    account,
    account_country,
    original_amount,
    price,
    amount
from {{ref("int_transactions_star")}}