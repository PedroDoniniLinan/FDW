with projections as (
    select
        id,
        calendar_date,
        simulation_set,
        transaction_type,
        budget_level,
        level_2,
        amount
    from {{ source('bronze', 'projections') }}
),

budget_mapping as (
    select
        budget_level,
        financial_level_1
    from {{ ref("map_budget_level") }}
)

select distinct
    s.transaction_type,
    s.budget_level,
    s.level_2 as level_1,
    m.financial_level_1,
    s.budget_level as budget_level_1
from projections s
    left join budget_mapping m on (s.budget_level = m.budget_level)
where transaction_type in ('Expenses')
{# where transaction_type in ('Income', 'Expenses') #}
order by 1, 2, 4