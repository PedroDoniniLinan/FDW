{{ config(
    materialized='table',
    tags=['refactored', 'main', 'mart', 'rated']
) }}

{% set levels = ['1', '2', '3'] %}

with

raw_balances as (
    select
        currency,
        calendar_date,
        level_1,
        level_2,
        level_3,
        source,
        balance
    from {{ ref("int_blc__allocation_balances_daily") }}
),

raw_emergency_reserves as (
    select level_3, emergency_reserves
    from {{ ref("dim_blc__emergency_reserves") }}
),

raw_allocation_targets as (
    select level_3, target_allocation
    from {{ ref("dim_blc__allocation_targets") }}
),

raw_prices as (
    select asset, currency, calendar_date, exchange_rate as price
    from {{ ref("fct_inv__rates_fiat_daily") }}
),

latest_positive_balance_date as (
    select max(calendar_date) as calendar_date
    from raw_balances
    where balance > 0 and currency != 'Original'
),

aggregated_balances as (
    select
        b.currency,
        b.calendar_date,
        b.level_1,
        b.level_2,
        b.level_3,
        b.source,
        sum(b.balance) as balance
    from raw_balances as b
    cross join latest_positive_balance_date as d
    where b.calendar_date = d.calendar_date
        and b.currency != 'Original'
        and b.currency = 'EUR'
        and b.balance > 0
    group by
        b.currency,
        b.calendar_date,
        b.level_1,
        b.level_2,
        b.level_3,
        b.source
),

available_balances as (
    select
        a.currency,
        a.calendar_date,
        a.level_1,
        a.level_2,
        a.level_3,
        a.source,
        coalesce(a.balance, 0) as balance,
        coalesce(a.balance, 0) - coalesce(e.emergency_reserves, 0) as available_balance,
        round(
            (
                (coalesce(a.balance, 0) - coalesce(e.emergency_reserves, 0))
                / sum(coalesce(a.balance, 0) - coalesce(e.emergency_reserves, 0)) over ()
            )::numeric,
            7
        ) as allocation,
        t.target_allocation,
        t.target_allocation - round(
            (
                (coalesce(a.balance, 0) - coalesce(e.emergency_reserves, 0))
                / sum(a.balance - coalesce(e.emergency_reserves, 0)) over ()
            )::numeric,
            7
        ) as allocation_delta,
        sum(coalesce(a.balance, 0) - coalesce(e.emergency_reserves, 0)) over ()
            * (
                t.target_allocation - round(
                    (
                        (coalesce(a.balance, 0) - coalesce(e.emergency_reserves, 0))
                        / sum(coalesce(a.balance, 0) - coalesce(e.emergency_reserves, 0)) over ()
                    )::numeric,
                    7
                )
            ) as balance_delta
    from aggregated_balances as a
    left join raw_emergency_reserves as e on a.level_3 = e.level_3
    full outer join raw_allocation_targets as t on a.level_3 = t.level_3
),

converted_currencies as (
    select
        p.currency,
        p.calendar_date,
        a.level_1,
        a.level_2,
        a.level_3,
        a.source,
        round((p.price * a.balance)::numeric, 4) as balance,
        round((p.price * a.available_balance)::numeric, 4) as available_balance,
        a.allocation,
        a.target_allocation,
        a.allocation_delta,
        round((p.price * a.balance_delta)::numeric, 4) as balance_delta
    from available_balances as a
    left join raw_prices as p
        on a.currency = p.asset
        and p.calendar_date = a.calendar_date
),

allocation_levels as (
    {% for l in levels %}
    select
        currency,
        '{{ l }}' as asset_level,
        level_1,
        case when '{{ l }}' = '1' then level_1 else level_2 end as level_2,
        level_{{ l }} as asset,
        round(sum(available_balance)::numeric, 5) as available_balance,
        round(sum(allocation)::numeric, 5) as allocation,
        round(sum(target_allocation)::numeric, 5) as target_allocation,
        round(sum(allocation_delta)::numeric, 5) as allocation_delta,
        round(sum(balance_delta)::numeric, 5) as balance_delta,
        case
            when currency in ('EUR', 'USD') then abs(round(sum(balance_delta)::numeric, 5)) > 200
            else abs(round(sum(balance_delta)::numeric, 5)) > 1300
        end as is_actionable
    from converted_currencies
    group by
        currency,
        asset_level,
        level_1,
        case when '{{ l }}' = '1' then level_1 else level_2 end,
        asset
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
),

final as (
    select
        currency,
        asset_level,
        level_1,
        level_2,
        asset,
        available_balance,
        allocation,
        target_allocation,
        allocation_delta,
        balance_delta,
        is_actionable
    from allocation_levels
)

select * from final
