{{ config(
    tags=['refactored', 'main', 'rated']
) }}

{% set currencies = ['BRL', 'USD', 'EUR', 'Original'] %}

with raw_transactions as (
    select
        transaction_id,
        source_transaction_id,
        calendar_date,
        transaction_description,
        asset,
        transaction_type,
        category,
        account,
        units,
        count_to_balance
    from {{ ref("fct_trx__cashflow_daily") }}
),

raw_rates as (
    select calendar_date, asset, currency, exchange_rate
    from {{ ref("fct_inv__rates_fiat_daily") }}
),

fiat_conversion_legs as (
    {% for c in currencies %}
        select
            md5(t.transaction_id::text || '{{ c }}')::uuid as fiat_transaction_id,
            t.transaction_id,
            t.source_transaction_id,
            t.calendar_date,
            t.transaction_description,
            t.asset,
            '{{ c }}' as currency,
            t.transaction_type,
            t.category,
            t.account,
            t.units,
            coalesce(
                p.exchange_rate,
                case when '{{ c }}' = 'Original' then 1 else 0 end
            ) as exchange_rate,
            case
                when '{{ c }}' = 'Original' then t.units * coalesce(p.exchange_rate, 1)
                else (t.units * coalesce(p.exchange_rate, 0))
            end as amount
        from raw_transactions as t
        left join raw_rates as p
            on (
                t.calendar_date = p.calendar_date
                and t.asset = p.asset
                and p.currency = '{{ c }}'
            )
        where t.count_to_balance
        {% if not loop.last %}union all{% endif %}
    {% endfor %}
),

final as (
    select
        fiat_transaction_id,
        transaction_id,
        source_transaction_id,
        calendar_date,
        transaction_description,
        asset,
        currency,
        transaction_type,
        category,
        account,
        units,
        exchange_rate,
        amount
    from fiat_conversion_legs
)

select * from final
