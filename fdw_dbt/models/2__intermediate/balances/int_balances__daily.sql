{%- set lookback_days = var('lookback_days', 30) -%}


{{ config(
    materialized='incremental',
    unique_key='balance_id',
    incremental_strategy='merge',
    incremental_predicates=["DBT_INTERNAL_DEST.calendar_date > " ~ get_latest_date(this, 'calendar_date', lookback_days, 'day')],
    on_schema_change=get_on_schema_change(),
    tags=['refactored', 'main', 'rated']
) }}

{%- set currencies = ['BRL', 'USD', 'EUR', 'Original'] -%}

{% for c in currencies %}
    select
        md5(ad.account || ad.asset || '{{ c }}' || ad.calendar_date)::uuid as balance_id,
        ad.account,
        ad.asset,
        '{{ c }}' as currency,
        ad.calendar_date,
        ad.is_end_of_period,
        ad.units,
        p.exchange_rate,
        case
            when '{{ c }}' = 'Original' then ad.units * coalesce(p.exchange_rate, 1)
            else (ad.units * coalesce(p.exchange_rate, 0))
        end as balance
    from {{ ref("int_holdings__daily") }} as ad
    left join {{ ref("int_rates__fiat_converted_daily") }} as p
        on (
            ad.calendar_date = p.calendar_date
            and ad.asset = p.asset
            and p.currency = '{{ c }}'
        )
    {%- if is_incremental() -%}
        where ad.calendar_date > {{ get_latest_date(this, 'calendar_date', lookback_days, 'days') }}
    {% endif %}
    {% if not loop.last %}union all{% endif %}
{% endfor %}
