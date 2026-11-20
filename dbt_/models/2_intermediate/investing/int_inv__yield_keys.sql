{{ config(materialized='table', tags=['refactored', 'main', 'rated']) }}

-- Every key (currency and budget levels) that has any balance or interest in the full history.
-- Not an event_time model, so it is never filtered to a batch: each yearly batch of agg_inv__yield_daily
-- spreads every one of these keys over every day, as the full-history model does.

select distinct currency, budget_level_1, budget_level_2, budget_level_3
from {{ ref('int_inv__yield_daily_aggregates') }}
