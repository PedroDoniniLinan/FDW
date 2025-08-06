{{ config(schema='silver', materialized='view') }}

with

    balances as (
        select
            case when original_currency in {{ fiat_currencies_ext() }} then 'All accounts' else b.account end as account,
            case when original_currency in {{ fiat_currencies_ext() }} then 'All accounts' else b.account_country end as account_country,
            b.currency,
            b.original_currency,
            b.level_1,
            b.level_2,
            b.level_3,
            b.source,
            b.calendar_date,
            b.is_end_of_period,
            sum(b.balance) as balance
        from {{ ref("int_fiat_balances_daily_star") }} b
        group by 
            1,
            2,
            b.currency,
            b.original_currency,
            b.level_1,
            b.level_2,
            b.level_3,
            b.source,
            b.calendar_date,
            b.is_end_of_period
    ),

    transactions as (
        select
            case when original_currency in {{ fiat_currencies_ext() }} then 'All accounts' else t.account end as account,
            case when original_currency in {{ fiat_currencies_ext() }} then 'All accounts' else t.account_country end as account_country,
            t.original_currency,
            t.currency,
            t.level_3,
            t.calendar_date,
            sum(amount) as amount
        from {{ ref("int_transactions_star") }} t
        where transaction_type = 'Income'
        group by 
            1,
            2,
            t.original_currency,
            t.currency,
            t.level_3,
            t.calendar_date
    )


select
    b.account,
    b.account_country,
    b.currency,
    b.original_currency,
    b.level_1,
    b.level_2,
    b.level_3,
    b.source,
    b.calendar_date,
    b.is_end_of_period,
    sum(balance) as balance,
    sum(amount) as yield,
    sum(amount)/sum(balance) as yield_rate
from balances b
left join transactions t on (
    b.level_3 = t.level_3
    and b.calendar_date = t.calendar_date
    and b.currency = t.currency
    and b.account = t.account
)
where b.balance > 0
group by
    b.account,
    b.account_country,
    b.currency,
    b.original_currency,
    b.level_1,
    b.level_2,
    b.level_3,
    b.source,
    b.calendar_date,
    b.is_end_of_period