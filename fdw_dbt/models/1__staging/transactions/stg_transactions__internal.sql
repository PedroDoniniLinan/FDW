{{ config(
    tags=['refactored', 'balance_validation', 'main']
) }}

{%- set src = source('bronze', 'transfers') -%}

select
    md5(id::text || '_tfo')::uuid as transaction_id,
    id as source_transaction_id,
    'Transfer' as transaction_type,
    source_acc || '->' || destination_acc as transaction_description,
    -amount as units,
    source_acc as account,
    calendar_date,
    'Transfer out' as category,
    currency as asset,
    true as count_to_balance
from {{ src }}
union all
select
    md5(id::text || '_tfi')::uuid as transaction_id,
    id as source_transaction_id,
    'Transfer' as transaction_type,
    destination_acc || '<-' || source_acc as transaction_description,
    amount as units,
    destination_acc as account,
    calendar_date,
    'Transfer in' as category,
    currency as asset,
    true as count_to_balance
from {{ src }}
