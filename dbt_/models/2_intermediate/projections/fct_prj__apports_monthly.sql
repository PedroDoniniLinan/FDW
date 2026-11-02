{{ config(materialized='view', tags=['refactored', 'projections']) }}

with

calendar as (
    select
        calendar_date,
        is_end_of_period
    from {{ ref('int_prj__calendar_monthly') }}
),

projections as (
    select
        calendar_date,
        simulation_set,
        amount
    from {{ ref('stg_projections__transactions') }}
),

aggregated as (
    select
        c.calendar_date,
        c.is_end_of_period,
        p.simulation_set,
        coalesce(sum(p.amount), 0) as apport
    from calendar as c
    left join projections as p on c.calendar_date = p.calendar_date
    group by 1, 2, 3
),

final as (
    select
        calendar_date,
        is_end_of_period,
        simulation_set,
        apport
    from aggregated
)

select * from final
