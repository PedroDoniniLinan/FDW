{{ config(schema='silver', materialized='view') }}

with

    balances as (
        select
            b.currency,
            b.level_1,
            b.level_2,
            b.level_3,
            b.calendar_date,
            sum(b.balance) as balance
        from {{ ref("int_fiat_balances_daily_star") }} b
        where currency != 'Original'
        group by 
            b.currency,
            b.level_1,
            b.level_2,
            b.level_3,
            b.calendar_date
        having sum(b.balance) > 0
    ),

    transactions as (
        select
            t.currency,
            t.level_1,
            t.level_2,
            t.level_3,
            t.calendar_date,
            sum(amount) as amount
        from {{ ref("int_transactions_star") }} t
        where currency != 'Original'
            and transaction_type = 'Income'
            and level_1 in ('Cash', 'Investments')
        {# and tag !~* 'exchange' #}
        group by 
            t.currency,
            t.level_1,
            t.level_2,
            t.level_3,
            t.calendar_date
    ),

    balance_yield as (
        select
            coalesce(b.currency, t.currency) as currency,
            coalesce(b.level_1, t.level_1) as level_1,
            coalesce(b.level_2, t.level_2) as level_2,
            coalesce(b.level_3, t.level_3) as level_3,
            coalesce(b.calendar_date, t.calendar_date) as calendar_date,
            sum(coalesce(balance, 0)) as balance,
            sum(coalesce(amount, 0)) as yield
        from balances b
        full outer join transactions t on (
            b.level_3 = t.level_3
            and b.calendar_date = t.calendar_date
            and b.currency = t.currency
        )
        group by 1, 2, 3, 4, 5
    ),

    prev_balance as (
        select
            *,
            lag(balance) over (partition by level_3, currency order by calendar_date) as prev_balance
        from balance_yield
    )


{# select *
from balances b
    left join transactions t on (
        b.original_currency = t.original_currency
        and b.calendar_date = t.calendar_date
        and b.currency = t.currency
        and b.account = t.account
    )
where b.currency = 'EUR'
and t.level_3 = 'BRAX'
and b.balance > 0
and b.calendar_date between '2020-01-01' and '2020-01-31'
order by b.calendar_date, t.level_3 #}

{# select
    date_trunc('year', calendar_date) as calendar_year,
    level_2,
    min(balance) as balance_min,
    max(balance) as balance_max,
    sum(yield) as yield
from prev_balance
where currency = 'EUR'
and date_trunc('year', calendar_date) = '2024-01-01'
group by 1, 2   #}

select *
from prev_balance
{# from balance_yield #}
where currency = 'EUR'
