{%- set src = source('bronze', 'external_transactions') -%}

select
    id::text||'_'||lower(transaction_type) as transaction_id,
    transaction_type,
    tag,
    amount,
    account,
    calendar_date,
    subcategory,
    currency,
    count_to_balance
from {{ src }}
where amount != 0