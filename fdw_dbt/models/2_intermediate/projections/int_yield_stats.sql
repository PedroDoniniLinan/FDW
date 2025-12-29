{{ config(schema='silver', materialized='view') }}

with

    asset_performance as (
        select
            level_3,
            avg(case when monthly_yield >= 1 then monthly_yield end) as avg_pos_yield,
            avg(case when monthly_yield < 1 then monthly_yield end) as avg_neg_yield,
            count(case when monthly_yield >= 1 then 1 end)::numeric/count(1) as pos_year_pct
        from (
            select
                level_3,
                date_trunc('year', calendar_date)::date as calendar_date,
                (exp(sum(ln(performance))))^(1.0/count(1)) as monthly_yield
            from {{ ref('int_price_yields_monthly') }}
            where currency = 'EUR'
            group by level_3, date_trunc('year', calendar_date)::date
        ) t
        group by level_3
    )

select
    a.level_3,
    a.avg_pos_yield,
    coalesce(a.avg_neg_yield, 1) as avg_neg_yield,
    a.pos_year_pct,
    target_allocation,
    a.avg_pos_yield * target_allocation as allocation_pos_yield,
    coalesce(a.avg_neg_yield, 1) * target_allocation as allocation_neg_yield
from asset_performance a
    inner join {{ ref('target_allocation') }} t on (a.level_3 = t.level_3)
where target_allocation > 0