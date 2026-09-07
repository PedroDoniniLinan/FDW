{{ config(schema='silver', materialized='view') }}

with

currency_calc as (
    select
        split_part(transaction_id, '_', 1) as transaction_id,
        account,
        calendar_date,
        currency,
        max(exchange_curency) as original_currency,
        sum(amount) as capital_gain
    from {{ ref("int_fiat_transactions") }}
    where amount != 0
        and transaction_type = 'Exchange'
    group by
        1,
        account,
        calendar_date,
        currency
),

final as (
    select
        account,
        calendar_date,
        currency,
        original_currency,
        sum(capital_gain) as capital_gain
    from currency_calc
    group by
        account,
        calendar_date,
        currency,
        original_currency
    )

select * from final
