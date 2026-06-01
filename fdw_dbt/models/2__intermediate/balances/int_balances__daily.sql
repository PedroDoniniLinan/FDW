{{ config(
    materialized='incremental',
    unique_key='balance_id',
    incremental_strategy='merge',
    tags=['refactored', 'main', 'rated']
) }}

{%- set currencies = ['BRL', 'USD', 'EUR', 'Original'] -%}
{%- set lookback_days = var('lookback_days', 30) -%}

{% for c in currencies %}
select
    md5(ad.account || ad.asset || '{{c}}' || ad.calendar_date)::uuid as balance_id,
    ad.account,
    ad.asset,
    '{{c}}' as currency,
    ad.calendar_date,
    ad.is_end_of_period,
    ad.units,
    p.exchange_rate,
    case when '{{c}}' = 'Original' then ad.units*coalesce(p.exchange_rate, 1)
        else (ad.units*coalesce(p.exchange_rate, 0))
    end as balance
from {{ref("int_holdings__daily")}} ad
    left join {{ref("int_rates__fiat_converted_daily")}} p on (
        ad.calendar_date = p.calendar_date
        and ad.asset = p.asset
        and p.currency = '{{c}}'
    )
{%- if is_incremental() -%}
where ad.calendar_date > (select max(calendar_date) - interval '{{ lookback_days }} days' from {{ this }})
{% endif %}
{% if not loop.last %}union all{% endif %}{% endfor %}