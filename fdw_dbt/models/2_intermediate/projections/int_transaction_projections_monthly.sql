{{ config(schema='silver', materialized='view') }}

select
    calendar_date,
    is_end_of_period,
    simulation_set,
    frequency,
    source,
    transaction_type,
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
        t.level_1,
        coalesce(t.amount, 0) as amount
    from {{ ref("src_projection_grid") }} g
    left join {{ ref("src_projections") }} t on (
        g.calendar_date = t.calendar_date
    )
    left join {{ ref('expenses_categories') }} ec on (
        t.level_1 = ec.level_1
    )
    left join {{ ref('income_categories') }} ic on (
        t.level_1 = ec.level_2
    )
)
group by 1, 2, 3, 4, 5, 6, 7
