with

    balances_changes as (
        select
            g.account,
            g.asset,
            g.calendar_date,
            g.is_end_of_period,
            coalesce(sum(t.amount), 0) as balance
        from {{ ref("int_shared__account_daily_grid") }} g
        left join {{ ref("int_transactions__united") }} t on (
            g.account = t.account
            and g.asset = t.asset
            and g.calendar_date = t.calendar_date
            and t.count_to_balance
        )
        group by g.account, g.asset, g.calendar_date, g.is_end_of_period
    ),

    balance_history as (
        select
            md5(account || asset || calendar_date)::uuid as balance_id,
            account,
            asset,
            calendar_date,
            is_end_of_period,
            sum(balance) over (partition by account, asset order by calendar_date) as balance
        from balances_changes
    )


select *,
    balance - lag(balance) over (partition by account, asset order by calendar_date) as day_change
from balance_history