{{ config(schema='silver', materialized='view') }}

{# select sum(target_allocation) from ( #}
select
    sa.set as simulation_set,
    t.asset_set,
    t.level_2,
    t.level_3,
    sa.allocation as level_2_allocation,
    t.level_3_allocation,
    (round(sa.allocation::numeric, 4) * 1e4 * round(level_3_allocation::numeric, 4) * 1e4)/1e8 as target_allocation
from (
    select distinct
        asa.set as asset_set,
        ic.level_2,
        ic.level_3,
        asa.allocation as level_3_allocation
    from {{ ref("asset_simulated_allocations") }} asa
    left join {{ ref("dim_income") }} ic on (asa.currency = ic.level_3)
) t
inner join {{ ref("simulated_allocations") }} sa on (t.asset_set = sa.asset_set and t.level_2 = sa.level_2)
where sa.set = 7
{# ) t #}