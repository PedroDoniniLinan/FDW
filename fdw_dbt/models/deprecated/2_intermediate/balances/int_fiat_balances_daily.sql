{{ config(schema='silver', materialized='table') }}
{% set currencies = ['BRL', 'USD', 'EUR', 'Original'] %}

{% for c in currencies %}
select
    ad.account,
    ad.currency as original_currency,
    '{{c}}' as currency,
    ad.calendar_date,
    ad.is_end_of_period,
    ad.balance as original_balance,
    p.price,
    case when '{{c}}' = 'Original' then ad.balance*coalesce(p.price, 1)
        else (ad.balance*coalesce(p.price, 0))
        {# else round((ad.balance*coalesce(p.price, 0))::numeric, 7) #}
    end as balance
from {{ref("int_balances_daily")}} ad
    left join {{ref("int_prices_daily")}} p on (
        ad.calendar_date = p.calendar_date
        and ad.currency = p.ticker
        and p.currency = '{{c}}'
    )
{# where balance > 0 #}
{% if not loop.last %}union all{% endif %}{% endfor %}