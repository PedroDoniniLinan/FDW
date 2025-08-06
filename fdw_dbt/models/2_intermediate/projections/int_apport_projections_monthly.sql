{{ config(schema='silver', materialized='view') }}

select
    calendar_date,
    is_end_of_period,
    simulation_set,
    coalesce(sum(amount), 0) as apport
from {{ ref("int_transaction_projections_monthly") }}
group by calendar_date, is_end_of_period, simulation_set