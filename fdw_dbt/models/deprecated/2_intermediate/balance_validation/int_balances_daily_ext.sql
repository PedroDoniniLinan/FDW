{{ config(schema='silver', materialized='view') }}

-- Daily balances including transactions that do not count to balance

with

    account_daily_grid as (
        select 
            t.account, 
            t.currency, 
            g.calendar_date,
            g.is_end_of_period
        from {{ ref('src_daily_grid') }} g
        cross join (select distinct account, currency from {{ ref('stg_transactions') }}) t
    ),

    balances_changes as (
        select
            g.account,
            g.currency,
            g.calendar_date,
            g.is_end_of_period,
            coalesce(sum(t.amount), 0) as balance
        from account_daily_grid g
        left join {{ ref('stg_transactions') }} t on (
            g.account = t.account
            and g.currency = t.currency
            and g.calendar_date = t.calendar_date
        )
        group by g.account, g.currency, g.calendar_date, g.is_end_of_period
    ),

    balance_history as (
        select
            account,
            currency,
            calendar_date,
            is_end_of_period,
            {# sum(balance) over (partition by account, currency order by calendar_date) as balance #}
            sum({{round_amount('balance', 'currency')}}) over (partition by account, currency order by calendar_date) as balance
        from balances_changes
    )


select *,
    balance - lag(balance) over (partition by account, currency order by calendar_date) as day_change
from balance_history