{{ config(schema='silver', materialized='view') }}


select
    account,
    calendar_date,
    currency,
    original_currency,
    sum(capital_gain) as capital_gain
from (
    select
        split_part(transaction_id, '_', 1) as transaction_id,
        account,
        calendar_date,
        currency,
        max(case 
            when currency = 'Original' then original_currency 
            when label != 'Sale' then null 
            when original_currency = currency then split_part(tag, '<-', 1) 
            when split_part(tag, '<-', 1) = currency then original_currency
            when original_currency in {{ fiat_currencies_ext() }} then split_part(tag, '<-', 1) 
            else original_currency
        end) as original_currency,
        sum(amount) as capital_gain
    from {{ ref("int_fiat_transactions") }}
    where amount != 0
        and transaction_type = 'Exchange'
    group by
        1,
        account,
        calendar_date,
        currency
) t
group by
    account,
    calendar_date,
    currency,
    original_currency