{{ config(
    materialized='table',
    tags=['refactored', 'main', 'rated'],
    post_hook=[
        "create unique index if not exists idx_rate_id on {{ this }} (rate_id)",
        "create index if not exists idx_calendar_date on {{ this }} (calendar_date)"
        ]
) }}

with

linear_regression as (
    select
        asset,
        exchange_asset,
        calendar_date,
        exchange_rate,
        (
            lead(calendar_date) over (partition by asset, exchange_asset order by calendar_date) - interval '1 day'
        )::date as next_calendar_date,
        lead(exchange_rate) over (partition by asset, exchange_asset order by calendar_date) as next_exchange_rate,
        (lead(exchange_rate) over (partition by asset, exchange_asset order by calendar_date) - exchange_rate)::numeric
        / (lead(calendar_date) over (partition by asset, exchange_asset order by calendar_date) - calendar_date) as step
    from {{ ref("int_rates__united") }}
),

daily_prices as (
    select
        l.asset,
        l.exchange_asset,
        g.calendar_date,
        g.is_end_of_period,
        md5(l.asset || l.exchange_asset || g.calendar_date)::uuid as rate_id,
        case
            when l.exchange_rate < 0.01 then (g.calendar_date - l.calendar_date) * coalesce(l.step, 0) + l.exchange_rate
            else ((g.calendar_date - l.calendar_date) * coalesce(l.step, 0) + l.exchange_rate)
        end as exchange_rate
    from linear_regression as l
    left join {{ ref("int_shared__daily_grid") }} as g on (
        g.calendar_date between l.calendar_date and coalesce(l.next_calendar_date, l.calendar_date)
    )
)

select
    rate_id,
    calendar_date,
    is_end_of_period,
    asset,
    exchange_asset,
    exchange_rate
from daily_prices
