{{ config(schema='silver', materialized='view') }}

with

    price_change as (
        select 
            *, 
            lag(original_balance) over (partition by original_currency, currency, account order by calendar_date) as prev_original_balance,
            lag(price) over (partition by original_currency, currency, account order by calendar_date) as prev_price,
            price - lag(price) over (partition by original_currency, currency, account order by calendar_date) as price_delta
        from {{ref("int_fiat_balances_daily")}}
    ),

    daily_capital_gain as (
        select 
            pc.account,
            pc.original_currency,
            pc.currency,
            pc.calendar_date,
            pc.is_end_of_period,
            pc.prev_original_balance,
            pc.original_balance,
            pc.price,
            pc.price_delta,
            eg.capital_gain as exchange_capital_gains,
            pc.price_delta*coalesce(pc.prev_original_balance, 0) as dod_capital_gain
        from price_change pc
            left join {{ref("int_exchange_gains")}} eg on (
                pc.account = eg.account
                and pc.original_currency = eg.original_currency
                and pc.currency = eg.currency
                and pc.calendar_date = eg.calendar_date
            )
        where pc.currency != 'Original'
    )

select *,
    coalesce(exchange_capital_gains, 0) + coalesce(dod_capital_gain, 0) as daily_capital_gain
from daily_capital_gain
