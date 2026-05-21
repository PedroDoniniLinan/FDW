with

    holdings_changes as (
        select
            g.account,
            g.asset,
            g.calendar_date,
            g.is_end_of_period,
            coalesce(sum(t.amount), 0) as units
        from {{ ref("int_shared__account_daily_grid") }} g
        left join {{ ref("int_transactions__united") }} t on (
            g.account = t.account
            and g.asset = t.asset
            and g.calendar_date = t.calendar_date
            and t.count_to_balance
        )
        group by g.account, g.asset, g.calendar_date, g.is_end_of_period
    ),

    holding_history as (
        select
            md5(account || asset || calendar_date)::uuid as holding_id,
            account,
            asset,
            calendar_date,
            is_end_of_period,
            sum(units) over (partition by account, asset order by calendar_date) as units
        from holdings_changes
    )


select *,
    units - lag(units) over (partition by account, asset order by calendar_date) as day_change
from holding_history