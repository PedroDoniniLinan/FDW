{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    unique_key='fiat_transaction_id',
    event_time='calendar_date',
    begin='2019-01-01',
    batch_size='month',
    lookback=2,
    tags=['refactored', 'main', 'rated']
) }}

with

raw_balances as (
    select
        account,
        asset,
        currency,
        calendar_date,
        units,
        exchange_rate,
        is_end_of_period
    from {{ ref("fct_blc__balances_daily", event_time='calendar_date') }}
),

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
    from raw_balances as d
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
),

final as (
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
)

select * from final
