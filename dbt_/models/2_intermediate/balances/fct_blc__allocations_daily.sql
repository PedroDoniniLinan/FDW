{{ config(
    tags=['refactored', 'main', 'intermediate']
) }}

with

raw_balances as (
    select
        asset,
        currency,
        calendar_date,
        balance
    from {{ ref("fct_blc__balances_daily") }}
),

raw_categories as (
    select
        category,
        transaction_type,
        budget_level_1,
        budget_level_2,
        budget_level_3
    from {{ ref("dim_trx__categories") }}
),

raw_emergency_reserves as (
    select
        budget_level_3,
        emergency_reserves
    from {{ ref("dim_blc__emergency_reserves") }}
),

raw_allocation_targets as (
    select
        budget_level_3,
        target_allocation
    from {{ ref("dim_blc__allocation_targets") }}
),

latest_allocation_balances as (
    select
        b.currency,
        b.calendar_date,
        c.budget_level_1,
        c.budget_level_2,
        c.budget_level_3,
        c.budget_level_1 as source,
        sum(b.balance) as balance
    from raw_balances as b
    left join raw_categories as c
        on b.asset = c.category
        and c.transaction_type = 'Income'
    where b.calendar_date = (
        select max(calendar_date)
        from raw_balances
        where balance > 0 and currency != 'Original'
    )
        and b.currency = 'EUR'
    group by 1, 2, 3, 4, 5
),

allocation_positions as (
    select
        a.currency,
        a.calendar_date,
        a.budget_level_1,
        a.budget_level_2,
        a.budget_level_3,
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
    from latest_allocation_balances as a
    left join raw_emergency_reserves as e on a.budget_level_3 = e.budget_level_3
    full outer join raw_allocation_targets as t on a.budget_level_3 = t.budget_level_3
),

final as (
    select
        currency,
        calendar_date,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        source,
        balance,
        available_balance,
        allocation,
        target_allocation,
        allocation_delta,
        balance_delta
    from allocation_positions
)

select * from final
