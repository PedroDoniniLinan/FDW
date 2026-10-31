{{ config(
    tags=['refactored', 'main']
) }}

with

raw_targets as (
    select
        level_3,
        target_balance
    from {{ ref("target_cash_reserves") }}
),

raw_balances as (
    select
        asset,
        balance,
        account,
        currency,
        calendar_date
    from {{ ref("fct_blc__balances_daily") }}
),

targets as (
    select
        level_3,
        sum(target_balance) as emergency_reserves
    from raw_targets
    where level_3 is not null
    group by level_3
),

latest_balance_date as (
    select max(calendar_date) as calendar_date
    from raw_balances
),

excluded_balance as (
    select
        b.asset as level_3,
        sum(b.balance) as emergency_reserves
    from raw_balances as b
    cross join latest_balance_date as d
    where b.currency = 'EUR'
        and (
            b.account in ('Payoneer', 'Nubank C', 'Coverflex', 'Klarna')
            or (b.account = 'Wise D' and b.asset != 'USD W')
        )
        and b.calendar_date = d.calendar_date
    group by b.asset
),

unioned_reserves as (
    select level_3, emergency_reserves from excluded_balance
    union all
    select level_3, emergency_reserves from targets
),

aggregated_reserves as (
    select
        level_3,
        sum(emergency_reserves) as emergency_reserves
    from unioned_reserves
    group by level_3
),

final as (
    select
        level_3,
        emergency_reserves
    from aggregated_reserves
)

select * from final
