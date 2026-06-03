{{ config(
    materialized='incremental',
    unique_key='fiat_transaction_id',
    incremental_strategy='merge',
    tags=['refactored', 'main', 'rated']
) }}
{%- set lookback_days = var('lookback_days', 30) -%}
{%- set lookback_days__window = var('lookback_days', 30) + 2 -%}

with

exchange_rate_change as (
    select
        d.*,
        lag(d.units) over
            (partition by d.asset, d.currency, d.account order by d.calendar_date) as prev_units,
        lag(d.exchange_rate) over
            (partition by d.asset, d.currency, d.account order by d.calendar_date) as prev_exchange_rate,
        d.exchange_rate
            - lag(d.exchange_rate) over
                (partition by d.asset, d.currency, d.account order by d.calendar_date) as exchange_rate_delta
    from {{ ref("int_balances__daily") }} as d
    {% if is_incremental() -%}
        where d.calendar_date > {{ get_latest_date(this, 'calendar_date', lookback_days, 'days') }}
    {% endif -%}
),

daily_capital_gain as (
    select
        pc.account,
        pc.asset,
        pc.currency,
        pc.calendar_date,
        pc.is_end_of_period,
        pc.prev_units,
        pc.units,
        pc.exchange_rate,
        pc.exchange_rate_delta,
        md5(pc.account || pc.calendar_date || pc.currency || pc.asset || 'dod')::uuid as fiat_transaction_id,
        pc.exchange_rate_delta * coalesce(pc.prev_units, 0) as amount
    from exchange_rate_change as pc
    where
        pc.currency != 'Original'
        {% if is_incremental() -%}
            and pc.calendar_date > {{ get_latest_date(this, 'calendar_date', lookback_days, 'days') }}
        {% endif -%}
)

select
    fiat_transaction_id,
    calendar_date,
    is_end_of_period,
    account,
    asset,
    currency,
    prev_units,
    units,
    exchange_rate,
    exchange_rate_delta,
    amount
from daily_capital_gain
where
    amount is not null
    and amount != 0
