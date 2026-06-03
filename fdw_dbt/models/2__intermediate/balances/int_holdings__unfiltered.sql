{{ config(
    materialized='table',
    tags=['refactored', 'balance_validation', 'main']
) }}

with

holdings_changes as (
    select
        g.account,
        g.asset,
        g.calendar_date,
        g.is_end_of_period,
        coalesce(sum(t.units), 0) as units
    from {{ ref("int_shared__account_daily_grid") }} as g
    left join {{ ref("int_transactions__all") }} as t
        on (
            g.account = t.account
            and g.asset = t.asset
            and g.calendar_date = t.calendar_date
        )
    group by g.account, g.asset, g.calendar_date, g.is_end_of_period
),

holding_history as (
    select
        account,
        asset,
        calendar_date,
        is_end_of_period,
        md5(account || asset || calendar_date)::uuid as holding_id,
        sum(units) over (partition by account, asset order by calendar_date) as units
    from holdings_changes
)


select
    holding_id,
    calendar_date,
    account,
    asset,
    is_end_of_period,
    units
from holding_history
