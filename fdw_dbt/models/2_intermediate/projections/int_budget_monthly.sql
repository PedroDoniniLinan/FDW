{{ config(schema='silver', materialized='view') }}

with

    projections as (
        select
            calendar_date,
            'Projection '||simulation_set as label,
            frequency as source,
            transaction_type,
            level_1,
            amount
        from {{ ref("int_transaction_projections_monthly") }}
        where level_1 is not null
    ),

    interest_projections as (
        select
            calendar_date as calendar_date,
            'Projection '||simulation_set as label,
            'Yearly' as source,
            'Income' as transaction_type,
            'Investments' as level_1,
            interest as amount
        from {{ source('silver', 'balance_projections') }}
    ),

    actuals as (
        select 
            (date_trunc('month', calendar_date))::date as calendar_date,
            'Actuals' as label,
            case 
                when t.source in ('Cash', 'Investments') then 'Yearly' 
                when t.transaction_type = 'Income' then 'Monthly'
                when t.transaction_type = 'Expenses' then t.source
                else 'Other'
            end as source,
            transaction_type,
            case 
                when t.source in ('Cash', 'Investments') then 'Investments' 
                when t.transaction_type = 'Income' then t.level_2
                when t.transaction_type = 'Expenses' then t.level_1
                else 'Other'
            end as level_1,
            sum(amount) as amount
        from {{ ref("int_transactions_star") }} t
        where transaction_type in ('Income', 'Expenses')
            and currency = 'EUR'
            and calendar_date >= '2024-01-01'
        group by 1, 2, 3, 4, 5
    )

select *
from projections
union all
select *
from interest_projections
union all
select *
from actuals