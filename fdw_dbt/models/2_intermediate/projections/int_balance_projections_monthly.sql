{{ config(schema='silver', materialized='view') }}

with

    balance_projections as (
        select
            calendar_date,
            is_end_of_period,
            'Projection '||simulation_set::text as label,
            balance
        from {{ source('silver', 'balance_projections') }}
    ),

    actuals as (
        select 
            date_trunc('month', calendar_date)::date as calendar_date,
            is_end_of_period,
            'Actuals' as label,
            sum(balance) as balance
        from {{ ref('int_fiat_balances_daily') }} 
        where currency = 'EUR'
            and is_end_of_period ~* 'month'
        group by calendar_date, is_end_of_period
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
    1000000 as balance
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