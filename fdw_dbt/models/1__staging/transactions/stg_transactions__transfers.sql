{%- set src = source('bronze', 'transfers') -%}

select
    id::text||'_tfo' as transaction_id,
    'Transfer' as transaction_type,
    source_acc||'->'||destination_acc as tag,
    -amount as amount,
    source_acc as account,
    calendar_date,
    'Transfer out' as subcategory,
    currency,
    true as count_to_balance
from {{ src }}
union all
select
    id::text||'_tfi' as transaction_id,
    'Transfer' as transaction_type,
    destination_acc||'<-'||source_acc as tag,
    amount,
    destination_acc as account,
    calendar_date,
    'Transfer in' as subcategory,
    currency,
    true as count_to_balance
from {{ src }}