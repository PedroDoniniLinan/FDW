{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    unique_key='balance_id',
    event_time='calendar_date',
    begin='2019-01-01',
    batch_size='month',
    lookback=2,
    on_schema_change=get_on_schema_change(),
    tags=['refactored', 'main', 'rated']
) }}

{%- set currencies = ['BRL', 'USD', 'EUR', 'Original'] -%}

with raw_holdings as (
    select
        holding_id,
        account,
        asset,
        calendar_date,
        is_end_of_period,
        units
    from {{ ref("fct_blc__holdings_daily") }}
),

raw_rates as (
    select
        asset,
        currency,
        exchange_rate,
        calendar_date
    from {{ ref("fct_inv__rates_fiat_daily") }}
),

balance_legs as (
    {%- for c in currencies %}
        select
            md5(h.holding_id || '{{ c }}')::uuid as balance_id,
            h.account,
            h.asset,
            '{{ c }}' as currency,
            h.calendar_date,
            h.is_end_of_period,
            h.units,
            r.exchange_rate,
            case
                when '{{ c }}' = 'Original' then h.units * coalesce(r.exchange_rate, 1)
                else (h.units * coalesce(r.exchange_rate, 0))
            end as balance
        from raw_holdings as h
        left join raw_rates as r
            on (
                h.calendar_date = r.calendar_date
                and h.asset = r.asset
                and r.currency = '{{ c }}'
            )
        {%- if not loop.last %}union all{% endif -%}
    {% endfor %}
),

final as (
    select
        balance_id,
        account,
        asset,
        currency,
        calendar_date,
        is_end_of_period,
        units,
        exchange_rate,
        balance
    from balance_legs
)

select * from final
