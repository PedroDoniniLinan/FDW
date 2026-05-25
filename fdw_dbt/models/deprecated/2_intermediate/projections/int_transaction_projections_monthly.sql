{{ config(schema='silver', materialized='view') }}

select
    calendar_date,
    is_end_of_period,
    simulation_set,
    frequency,
    source,
    transaction_type,
    budget_level,
    level_1,
    sum(amount) as amount
from (
    select distinct
        g.calendar_date,
        g.is_end_of_period,
        t.simulation_set,
        coalesce(ec.frequency, case when ic.source = 'Investment' then 'Yearly' else 'Monthly' end) as frequency,
        ic.source,
        t.transaction_type,
        t.budget_level,
        t.level_1,
        coalesce(t.amount, 0) as amount
    from {{ ref("src_projection_grid") }} g
    left join {{ ref("src_projections") }} t on (
        g.calendar_date = t.calendar_date
    )
    left join {{ ref('dim_expenses') }} ec on (
        t.level_1 = ec.level_1
    )
    left join {{ ref('dim_income') }} ic on (
        t.level_1 = ec.level_2
    )
)
group by
    calendar_date,
    is_end_of_period,
    simulation_set,
    frequency,
    source,
    transaction_type,
    budget_level,
    level_1
