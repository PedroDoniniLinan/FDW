{{ config(schema='gold', materialized='table') }}

select *
from {{ ref("int_budget_monthly") }} t