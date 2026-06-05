{{ config(
    tags= ['refactored', 'projections']
) }}

{%- set src = source('bronze', 'projections') -%}

select
    transaction_id,
    calendar_date,
    simulation_set,
    transaction_type,
    financial_level_1,
    budget_level_1,
    amount
from (
    select
        s.calendar_date,
        s.simulation_set,
        s.transaction_type,
        m.financial_level_1,
        s.level_2 as budget_level_1,
        md5(s.id::text || '_' || lower(s.transaction_type) || '_proj')::uuid as transaction_id,
        case when s.transaction_type = 'Expenses' then -1 * s.amount else s.amount end as amount
    from {{ src }} as s
    left join {{ ref("map_budget_level") }} as m on (s.budget_level = m.budget_level)
)
