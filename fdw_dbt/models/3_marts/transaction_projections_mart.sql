{{ config(schema='gold', materialized='table') }}

select
    t.calendar_date,
    t.is_end_of_period,
    t.frequency,
    t.simulation_set,
    t.transaction_type,
    t.level_1,
    t.amount,
    case when t.transaction_type = 'Expenses' then -t.amount else t.amount end as abs_amount
from {{ ref("int_transaction_projections_monthly") }} t
union all
select
    calendar_date as calendar_date,
    is_end_of_period,
    'Yearly' as frequency,
    simulation_set,
    'Income' as transaction_type,
    'Investments' as level_1,
    sum(interest) as amount,
    sum(interest) as abs_amount
from {{ source('silver', 'balance_projections') }}
group by
    calendar_date,
    is_end_of_period,
    simulation_set
