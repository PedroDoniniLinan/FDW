{{ config(schema='bronze', materialized='view') }}

select
    calendar_date,
    simulation_set,
    transaction_type,
    budget_level,
    level_2 as level_1,
    case when transaction_type = 'Expenses' then -1 * amount else amount end as amount
from {{ source('bronze', 'projections') }}