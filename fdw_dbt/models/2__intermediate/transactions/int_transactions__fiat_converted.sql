{% set currencies = ['BRL', 'USD', 'EUR', 'Original'] %}

{% for c in currencies %}
select
    md5(t.transaction_id::text || '{{c}}')::uuid as fiat_transaction_id,
    t.transaction_id,
    t.source_transaction_id,
    t.calendar_date,
    t.transaction_description,
    t.asset,
    '{{c}}' as currency,
    t.transaction_type,
    t.category,
    t.account,
    t.units,
    coalesce(
        p.exchange_rate,
        case when '{{c}}' = 'Original' then 1 else 0 end
    ) as exchange_rate,
    case when '{{c}}' = 'Original' then t.units*coalesce(p.exchange_rate, 1)
        else (t.units*coalesce(p.exchange_rate, 0))
    end as amount
from {{ref("int_transactions__all")}} t
    left join {{ref("int_rates__fiat_converted_daily")}} p on (
        t.calendar_date = p.calendar_date
        and t.asset = p.asset
        and p.currency = '{{c}}'
    )
where count_to_balance
{% if not loop.last %}union all{% endif %}{% endfor %}
