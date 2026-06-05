{{ config(
    tags=['refactored', 'balance_validation', 'main']
) }}

{%- set src = source('bronze', 'external_transactions') -%}

select
    transaction_id,
    source_transaction_id,
    transaction_type,
    transaction_description,
    units,
    account,
    calendar_date,
    category,
    asset,
    count_to_balance
from (
    select
        id as source_transaction_id,
        transaction_type,
        tag as transaction_description,
        amount as units,
        account,
        calendar_date,
        subcategory as category,
        currency as asset,
        count_to_balance,
        md5(id::text || '_' || lower(transaction_type))::uuid as transaction_id
    from {{ src }}
    where amount != 0
)
