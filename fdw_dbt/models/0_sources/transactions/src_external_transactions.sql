{{ config(schema='bronze', materialized='view') }}

select
    id::text||'_'||lower(transaction_type) as transaction_id,
    transaction_type,
    tag,
    {# {{round_amount('amount', 'currency')}} as amount, #}
    amount,
    account,
    calendar_date,
    subcategory,
    currency,
    count_to_balance
from {{ source('bronze', 'external_transactions') }}
where amount != 0
{# where {{round_amount('amount', 'currency')}} != 0 #}
-- and count_to_balance