{%- set src = source('bronze', 'projections') -%}

select
    md5(id::text||'_'||lower(transaction_type)||'_proj')::uuid as transaction_id,
    calendar_date,
    simulation_set,
    transaction_type,
    budget_level,
    level_2 as level_1,
    case when transaction_type = 'Expenses' then -1 * amount else amount end as amount
from {{ src }}