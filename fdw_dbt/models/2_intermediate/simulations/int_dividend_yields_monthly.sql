{{ config(schema='silver', materialized='view') }}

with

    target_assets as (
        select distinct level_3
        from {{ref("target_allocation")}}
    ),

    dividends as (
        select
            i.currency,
            date_trunc('month', i.calendar_date)::date as calendar_date,
            i.level_3,
            i.label as ticker,
            sum(i.amount) as amount
        from {{ref("int_transactions_star")}} i
            inner join target_assets t on (i.level_3 = t.level_3)
        where transaction_type = 'Income'
            and transaction_id is not null
            and source not in ('Work', 'Other sources')
            and currency = 'EUR'
        group by 1, 2, 3, 4
    ),

    avg_balances as (
        select
            i.currency,
            date_trunc('month', i.calendar_date)::date as calendar_date,
            i.original_currency as ticker,
            i.level_3,
            avg(balance) as balance
        from {{ref("int_fiat_balances_daily_star")}} i
            inner join target_assets t on (i.level_3 = t.level_3)
        where currency = 'EUR'
        group by 1, 2, 3, 4
    )

select
    d.currency,
    d.calendar_date,
    d.level_3,
    d.ticker,
    d.amount,
    a.balance,
    (d.amount/a.balance) as performance
    {# round((d.amount/a.balance)::numeric, 5) as performance #}
from dividends d
    left join avg_balances a on (
        d.calendar_date = a.calendar_date
        and d.ticker = a.ticker
    )
where balance is not null
