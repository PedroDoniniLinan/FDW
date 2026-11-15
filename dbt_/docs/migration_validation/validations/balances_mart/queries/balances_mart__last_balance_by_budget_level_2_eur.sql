-- Test: balance on the last calendar_date of each budget_level_2, EUR only (sum of balance on that date), legacy vs current.
-- Dimension mapping: budget_level_2 -> level_2 (legacy level_2 and current budget_level_2 hold the same category values).
-- Filtered to currency EUR so amounts are never mixed across currencies.
-- Each side uses its own last date per budget_level_2, so a side that ends earlier shows as a mismatch.
-- Tolerance: a difference below 0.1% of the legacy amount is ok, with a floor of 1 for small amounts.

with

legacy_dated as (
    select
        coalesce(level_2, '<null>') as budget_level_2,
        calendar_date,
        balance,
        max(calendar_date) over (partition by coalesce(level_2, '<null>')) as last_date
    from gold.balances_mart
    where currency = 'EUR'
),

legacy as (
    select
        budget_level_2,
        coalesce(sum(balance), 0)::float8 as legacy_amount
    from legacy_dated
    where calendar_date = last_date
    group by 1
),

current_dated as (
    select
        coalesce(budget_level_2, '<null>') as budget_level_2,
        calendar_date,
        balance,
        max(calendar_date) over (partition by coalesce(budget_level_2, '<null>')) as last_date
    from "prod"."gold"."fct_blc__balances_enriched_daily"
    where currency = 'EUR'
),

current_side as (
    select
        budget_level_2,
        coalesce(sum(balance), 0)::float8 as current_amount
    from current_dated
    where calendar_date = last_date
    group by 1
)

select
    coalesce(l.budget_level_2, c.budget_level_2) as budget_level_2,
    round(l.legacy_amount::numeric, 2) as legacy_amount,
    round(c.current_amount::numeric, 2) as current_amount,
    round((coalesce(c.current_amount, 0) - coalesce(l.legacy_amount, 0))::numeric, 2) as amount_diff,
    case
        when l.budget_level_2 is null then 'missing_in_legacy'
        when c.budget_level_2 is null then 'missing_in_current'
        when abs(coalesce(c.current_amount, 0) - coalesce(l.legacy_amount, 0))
            <= greatest(1, 0.001 * abs(coalesce(l.legacy_amount, 0))) then 'ok'
        else 'mismatch'
    end as status
from legacy as l
full outer join current_side as c on l.budget_level_2 = c.budget_level_2
order by 1