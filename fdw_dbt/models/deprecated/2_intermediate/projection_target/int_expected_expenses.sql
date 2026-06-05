{{ config(schema='silver', materialized='view') }}

with

    past_expenses as (
        select
            avg(total_amount) as avg_amount_12m,
            percentile_cont(0.5) within group (order by total_amount) as median_amount_12m
        from (
            select
                calendar_date,
                sum(amount) as total_amount,
                sum(avg_amount_12m) as avg_amount_12m
            from {{ ref("int_avg_expenses_monthly_per_lvl2") }}
            {# where calendar_date = date_trunc('month', current_date) - interval '1 month' #}
            where calendar_date between current_date - interval '12 months' and current_date - interval '1 month'
            group by calendar_date
        ) t
    )

select 'Recent expenses' as estimate_type, -median_amount_12m as amount from past_expenses
union all
select 'High estimate' as estimate_type, 3300 as amount from past_expenses
union all
select 'Low estimate' as estimate_type, 2500 as amount from past_expenses
