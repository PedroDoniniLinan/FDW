{{ config(
    tags= ['refactored', 'projections']
) }}

{%- set src = source('bronze', 'projections') -%}

select
    md5(id::text||'_'||lower(transaction_type)||'_proj')::uuid as transaction_id,
    calendar_date,
    simulation_set,
    transaction_type,
    m.financial_level_1,
    level_2 as budget_level_1,
    case when transaction_type = 'Expenses' then -1 * amount else amount end as amount
from {{ src }} s
    left join {{ ref("map_budget_level") }} m on (s.budget_level = m.budget_level) 