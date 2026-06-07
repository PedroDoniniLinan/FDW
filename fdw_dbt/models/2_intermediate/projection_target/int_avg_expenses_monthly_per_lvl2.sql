{{ config(schema='silver', materialized='view') }}

with

    monthly_expenses as (
        select
            date_trunc('month', calendar_date)::date as calendar_date,
            source,
            level_1,
            level_2,
            sum(amount) as amount
        from {{ ref("int_transactions_star") }}
        where transaction_type = 'Expenses'
            and currency = 'EUR'
        group by
            date_trunc('month', calendar_date)::date,
            source,
            level_1,
            level_2
    ),

    date_grid as (
        select
            date_trunc('month', g.calendar_date)::date as calendar_date, 
            source, 
            level_1, 
            level_2
        from {{ ref("src_daily_grid") }} g
            cross join (
                select distinct source, level_1, level_2
                from {{ ref("int_transactions_star") }}
                where transaction_type = 'Expenses'
            )
        where g.is_end_of_period like '%month%'
    ),

    monthly_expenses_grid as (
        select
            g.calendar_date,
            g.source,
            g.level_1,
            g.level_2,
            coalesce(amount, 0) as amount
        from date_grid g
            left join monthly_expenses me on (
                g.calendar_date = me.calendar_date
                and g.source = me.source
                and g.level_1 = me.level_1
                and g.level_2 = me.level_2
            )
    )

select *,
    avg(amount) over (
    {# round(avg(amount) over ( #}
        partition by source, level_1, level_2
        order by calendar_date
        rows between 11 preceding and current row
    ) as avg_amount_12m
    {# ), 2) as avg_amount_12m #}
from monthly_expenses_grid
order by source, level_1, level_2, calendar_date