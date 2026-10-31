{{ config(
    tags= ['refactored', 'projections']
) }}

with projections as (
    select
        calendar_date,
        simulation_set,
        transaction_type,
        budget_level
    from {{ source('bronze', 'projections') }}
),

budget_mapping as (
    select
        budget_level,
        financial_level_1
    from {{ ref("map_budget_level") }}
),

final as (
    select
        md5(s.id::text || '_' || lower(s.transaction_type) || '_proj')::uuid as transaction_id,
        s.calendar_date,
        s.simulation_set,
        s.transaction_type,
        m.financial_level_1,
        s.budget_level as budget_level_1,
        case when s.transaction_type = 'Expenses' then -1 * s.amount else s.amount end as amount
    from projections s
    left join budget_mapping m on (s.budget_level = m.budget_level)
)

select * from final
