{{ config(schema='silver', materialized='view') }}

with

    income_categories as (
        select distinct level_2, level_3
        from {{ ref("income_categories") }}
    ),

    projections as (
        select
            calendar_date,
            'Projection '||simulation_set as label,
            frequency as source,
            transaction_type,
            budget_level,
            level_1,
            level_1 as level_2,
            level_1 as level_3,
            sum(amount) as amount
        from {{ ref("int_transaction_projections_monthly") }}
        where level_1 is not null
        group by
            calendar_date,
            simulation_set,
            frequency,
            transaction_type,
            budget_level,
            level_1
    ),

    interest_projections as (
        select
            b.calendar_date as calendar_date,
            'Projection '||b.simulation_set as label,
            'Yearly' as source,
            'Income' as transaction_type,
            'Investments' as budget_level,
            'Investments' as level_1,
            i.level_2,
            b.level_3,
            sum(interest) as amount
        from {{ source('silver', 'balance_projections') }} b
            left join income_categories i on (b.level_3 = i.level_3)
        group by b.calendar_date, b.simulation_set, i.level_2, b.level_3
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
            budget_level,
            case 
                when t.source in ('Cash', 'Investments') then 'Investments' 
                when t.transaction_type = 'Income' then t.level_2
                when t.transaction_type = 'Expenses' then t.level_1
                else 'Other'
            end as level_1,
            case 
                when t.source in ('Cash', 'Investments') then t.level_2
                when t.transaction_type = 'Income' then t.level_2
                when t.transaction_type = 'Expenses' then t.level_1
                else 'Other'
            end as level_2,
            case 
                when t.source in ('Cash', 'Investments') then t.level_3
                when t.transaction_type = 'Income' then t.level_2
                when t.transaction_type = 'Expenses' then t.level_1
                else 'Other'
            end as level_3,
            sum(amount) as amount
        from {{ ref("int_transactions_star") }} t
        where transaction_type in ('Income', 'Expenses')
            and currency = 'EUR'
            and calendar_date >= '2024-01-01'
        group by 1, 2, 3, 4, 5, 6, 7, 8
    )

select *
from projections
union all
select *
from interest_projections
union all
select *
from actuals