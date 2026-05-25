{{ config(schema='silver', materialized='view') }}

with

    start_dates as (
        {% for d in ['2019', '2020', '2021', '2022', '2023', '2024', '2025'] %}
        select distinct
            '{{ d }}-01-01'::date as start_date,
            calendar_date,
            time_grain
        from {{ ref("int_yields_agg_time_grains") }}
        where calendar_date >= '{{ d }}-01-01'::date
        {% if not loop.last %}union all{% endif %}
        {% endfor %}
    ),

    joined_subsets as (
        select
            s.start_date,
            s.calendar_date as start_date_calendar,
            y.*
        from start_dates s
            left join {{ ref("int_yields_agg_time_grains") }} y on (
                s.time_grain = y.time_grain
                and s.calendar_date >= y.calendar_date 
                and s.start_date <= y.calendar_date 
            )
    )

select 
    start_date::date,
    currency,
    start_date_calendar as calendar_date,
    time_grain,
    field,
    breakdown,
    sum(yield) as yield,
    {{ prod('1 + yield_rate') }} as performance,
    {{ prod('1 + yield_rate') }} - 1 as yield_rate
from joined_subsets
group by
    start_date,
    currency,
    start_date_calendar,
    time_grain,
    field,
    breakdown
order by start_date, calendar_date
{# order by start_date, start_date_calendar, calendar_date #}
    