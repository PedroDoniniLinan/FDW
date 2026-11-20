{{ config(schema='gold', materialized='table') }}

-- First and last date of the whole yield history. Kept as its own model, not inside
-- agg_inv__yield_periods, because a microbatch model filters every ref to an event_time model to its batch.
select
    min(calendar_date) as first_date,
    max(calendar_date) as last_date
from {{ ref('agg_inv__yield_daily') }}
