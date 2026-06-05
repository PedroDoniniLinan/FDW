{{ config(schema='silver', materialized='view') }}
{% set currencies = ['BRL', 'USD', 'EUR', 'Original'] %}

{% for c in currencies %}
select
    t.transaction_id,
    t.calendar_date,
    t.tag,
    t.currency as original_currency,
    '{{c}}' as currency,
    t.transaction_type,
    t.subcategory as label,
    t.account,
    t.amount as original_amount,
    p.price,
    case when '{{c}}' = 'Original' then t.amount*coalesce(p.price, 1)
        else (t.amount*coalesce(p.price, 0))
        {# else round((t.amount*coalesce(p.price, 0))::numeric, 4) #}
    end as amount
from {{ref("stg_transactions")}} t
    left join {{ref("int_prices_daily")}} p on (
        t.calendar_date = p.calendar_date
        and t.currency = p.ticker
        and p.currency = '{{c}}'
    )
where count_to_balance
{% if not loop.last %}union all{% endif %}{% endfor %}
