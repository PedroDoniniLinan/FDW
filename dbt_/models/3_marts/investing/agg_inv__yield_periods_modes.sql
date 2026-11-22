{{ config(schema='gold', materialized='table') }}

with

period_ends as (
    select distinct
        time_grain,
        calendar_date as period_end
    from {{ ref('agg_inv__yield_periods') }}
),

start_years as (
    select distinct date_part('year', period_end)::integer as start_year
    from period_ends
),

cumulative_windows as (
    select
        p.time_grain,
        p.period_end,
        y.start_year,
        (y.start_year::text || '-01-01')::date as window_start
    from period_ends as p
    cross join start_years as y
    where y.start_year <= date_part('year', p.period_end)
),

period_index as (
    select
        time_grain,
        period_end,
        row_number() over (partition by time_grain order by period_end) as period_idx
    from period_ends
),

cumulative_links as (
    select
        w.period_end as calendar_date,
        w.time_grain,
        w.start_year,
        r.aggregation_level,
        r.budget_level_3,
        r.budget_level_1,
        r.budget_level_2,
        r.currency,
        max(pe.period_idx) - min(pr.period_idx) + 1 as expected_periods,
        count(*) as period_count,
        count(case when r.yield <= -1 then 1 end) as invalid_yield_count,
        sum(case when r.yield > -1 then ln(1 + r.yield) end) as log_growth,
        sum(r.days_observed) as days_observed,
        sum(r.interest) as interest,
        sum(r.avg_balance * r.days_observed) / sum(r.days_observed) as avg_balance
    from cumulative_windows as w
    inner join period_index as pe
        on w.time_grain = pe.time_grain
        and w.period_end = pe.period_end
    inner join {{ ref('agg_inv__yield_periods') }} as r
        on w.time_grain = r.time_grain
        and r.calendar_date between w.window_start and w.period_end
    inner join period_index as pr
        on r.time_grain = pr.time_grain
        and r.calendar_date = pr.period_end
    group by 1, 2, 3, 4, 5, 6, 7, 8
),

cumulative_final as (
    select
        calendar_date,
        time_grain,
        aggregation_level,
        budget_level_3,
        budget_level_1,
        budget_level_2,
        currency,
        start_year,
        days_observed,
        avg_balance,
        interest,
        case
            when period_count = expected_periods and invalid_yield_count = 0
                then exp(log_growth) - 1
        end as yield
    from cumulative_links
),

cumulative_metrics as (
    select
        calendar_date,
        time_grain,
        aggregation_level,
        budget_level_3,
        budget_level_1,
        budget_level_2,
        currency,
        start_year,
        days_observed,
        avg_balance,
        interest,
        yield,
        case
            when yield > -1 then power(1 + yield, 365.0 / days_observed) - 1
        end as yield_annualized
    from cumulative_final
),

final as (
    select
        'current' as yield_mode,
        null::integer as start_year,
        calendar_date,
        time_grain,
        aggregation_level,
        budget_level_3,
        budget_level_1,
        budget_level_2,
        currency,
        days_observed,
        avg_balance,
        interest,
        yield,
        yield_annualized
    from {{ ref('agg_inv__yield_periods') }}

    union all

    select
        'cumulative' as yield_mode,
        start_year,
        calendar_date,
        time_grain,
        aggregation_level,
        budget_level_3,
        budget_level_1,
        budget_level_2,
        currency,
        days_observed,
        avg_balance,
        interest,
        yield,
        yield_annualized
    from cumulative_metrics
)

select * from final
