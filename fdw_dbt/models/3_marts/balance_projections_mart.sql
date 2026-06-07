{{ config(schema='gold', materialized='table') }}

select *
from {{ ref("int_balance_projections_monthly") }}