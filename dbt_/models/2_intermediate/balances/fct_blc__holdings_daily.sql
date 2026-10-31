{{ config(
    materialized='table',
    tags=['refactored', 'main']
) }}

with

raw_account_daily_grid as (
    select
        account,
        asset,
        calendar_date,
        is_end_of_period
    from {{ ref("int_com__account_calendar_daily") }}
),

raw_transactions as (
    select
        account,
        asset,
        calendar_date,
        units,
        count_to_balance
    from {{ ref("fct_trx__cashflow_daily") }}
),

holdings_changes as (
    select
        g.account,
        g.asset,
        g.calendar_date,
        g.is_end_of_period,
        coalesce(sum(t.units), 0) as units
    from raw_account_daily_grid as g
    left join raw_transactions as t
        on (
            g.account = t.account
            and g.asset = t.asset
            and g.calendar_date = t.calendar_date
            and t.count_to_balance
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
),


final as (
    select
        holding_id,
        calendar_date,
        account,
        asset,
        is_end_of_period,
        units
    from holding_history
)

select * from final
