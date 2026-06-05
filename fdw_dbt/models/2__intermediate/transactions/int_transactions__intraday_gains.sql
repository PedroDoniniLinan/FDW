{{ config(
    tags=['refactored', 'main', 'rated']
) }}

with

exchange_transactions as (
    select
        source_transaction_id,
        account,
        calendar_date,
        currency,
        max(case
            when currency = 'Original' then asset
            when category != 'Sale' then null
            when asset = currency then split_part(transaction_description, '<-', 1)
            when split_part(transaction_description, '<-', 1) = currency then asset
            when asset in {{ fiat_currencies_ext() }} then split_part(transaction_description, '<-', 1)
            else asset
        end) as asset,
        sum(amount) as amount
    from {{ ref("int_transactions__fiat_converted") }}
    where
        amount != 0
        and transaction_type = 'Exchange'
    group by
        source_transaction_id,
        account,
        calendar_date,
        currency
),

final_agg as (
    select
        calendar_date,
        account,
        currency,
        asset,
        md5(account || calendar_date || currency || asset || 'intraday')::uuid as fiat_transaction_id,
        sum(amount) as amount
    from exchange_transactions
    where asset is not null
    group by
        account,
        calendar_date,
        currency,
        asset
)

select
    fiat_transaction_id,
    calendar_date,
    account,
    currency,
    asset,
    amount
from final_agg
