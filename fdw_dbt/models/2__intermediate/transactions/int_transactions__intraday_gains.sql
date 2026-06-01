{{ config(
    tags=['refactored', 'main', 'rated']
) }}

select
    md5(account || calendar_date || currency || asset || 'intraday')::uuid as fiat_transaction_id,
    calendar_date,
    account,
    currency,
    asset,
    sum(amount) as amount
from (
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
    where amount != 0
        and transaction_type = 'Exchange'
    group by
        1,
        account,
        calendar_date,
        currency
) t
where asset is not null
group by
    account,
    calendar_date,
    currency,
    asset