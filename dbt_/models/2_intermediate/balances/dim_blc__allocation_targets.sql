{{ config(
    tags=['refactored', 'main']
) }}

with

raw_asset_allocations as (
    select
        set as asset_set,
        currency,
        allocation as level_3_allocation
    from {{ ref("asset_simulated_allocations") }}
),

raw_income_categories as (
    select
        budget_level_2,
        budget_level_3
    from {{ ref("dim_income") }}
),

raw_simulated_allocations as (
    select
        set as simulation_set,
        asset_set,
        level_2 as budget_level_2,
        allocation as level_2_allocation
    from {{ ref("simulated_allocations") }}
),

asset_allocations as (
    select distinct
        a.asset_set,
        i.budget_level_2,
        i.budget_level_3,
        a.level_3_allocation
    from raw_asset_allocations as a
    left join raw_income_categories as i
        on a.currency = i.budget_level_3
),

target_allocations as (
    select
        s.simulation_set,
        a.asset_set,
        a.budget_level_2,
        a.budget_level_3,
        s.level_2_allocation,
        a.level_3_allocation,
        (
            round(s.level_2_allocation::numeric, 4) * 1e4
            * round(a.level_3_allocation::numeric, 4) * 1e4
        ) / 1e8 as target_allocation
    from asset_allocations as a
    inner join raw_simulated_allocations as s
        on a.asset_set = s.asset_set
        and a.budget_level_2 = s.budget_level_2
    where s.simulation_set = 7
),

final as (
    select
        simulation_set,
        asset_set,
        budget_level_2,
        budget_level_3,
        level_2_allocation,
        level_3_allocation,
        target_allocation
    from target_allocations
)

select * from final
