{%- set src = source('bronze', 'external_transactions') -%}

select
    md5(id::text||'_'||lower(transaction_type))::uuid as transaction_id,
    transaction_type,
    tag as transaction_description,
    amount,
    account,
    calendar_date,
    subcategory as category,
    currency as asset,
    count_to_balance
from {{ src }}
where amount != 0