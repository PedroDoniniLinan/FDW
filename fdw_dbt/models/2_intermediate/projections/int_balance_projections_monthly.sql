{{ config(schema='silver', materialized='view') }}

with

    balance_projections as (
        select
            calendar_date,
            is_end_of_period,
            'Projection '||simulation_set::text as label,
            sum(balance) as balance
        from {{ source('silver', 'balance_projections') }}
        group by calendar_date, is_end_of_period, label
    ),

    actuals as (
        select 
            date_trunc('month', calendar_date)::date as calendar_date,
            time_grain as is_end_of_period,
            'Actuals' as label,
            sum(balance) as balance
        from {{ ref("balance_metrics") }} 
        where currency = 'EUR'
            and time_grain = 'month'
            and account != 'Nubank C'
        group by calendar_date, time_grain
    )

select *
from balance_projections
union all
select *
from actuals
union all
select distinct
    calendar_date,
    is_end_of_period,
    'Retirement goal' as label,
    700000 as balance
from balance_projections
union all
select distinct
    calendar_date,
    is_end_of_period,
    'House goal' as label,
    300000 as balance
from balance_projections
union all
select distinct
    calendar_date,
    is_end_of_period,
    'Car goal' as label,
    200000 as balance
from balance_projections