{{ config(
    tags=['refactored', 'main', 'rated']
) }}

with

    exchange_rate_change as (
        select 
            *, 
            lag(units) over (partition by asset, currency, account order by calendar_date) as prev_units,
            lag(exchange_rate) over (partition by asset, currency, account order by calendar_date) as prev_exchange_rate,
            exchange_rate - lag(exchange_rate) over (partition by asset, currency, account order by calendar_date) as exchange_rate_delta
        from {{ref("int_balances__daily")}}
    ),

    daily_capital_gain as (
        select
            md5(account || calendar_date || currency || asset || 'dod')::uuid as transaction_id,
            pc.account,
            pc.asset,
            pc.currency,
            pc.calendar_date,
            pc.is_end_of_period,
            pc.prev_units,
            pc.units,
            pc.exchange_rate,
            pc.exchange_rate_delta,
            pc.exchange_rate_delta*coalesce(pc.prev_units, 0) as amount
        from exchange_rate_change pc
        where pc.currency != 'Original'
    )

select *
from daily_capital_gain
where amount is not null
    and amount != 0
