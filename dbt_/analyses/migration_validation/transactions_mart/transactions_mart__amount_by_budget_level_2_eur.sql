-- Test: amount per budget_level_2, EUR only (sum of amount), legacy vs current.
-- Dimension mapping: budget_level_2 -> level_2 (legacy level_2 and current budget_level_2 hold the same values, e.g. 'House bills', 'Bonds BR').
-- Filtered to currency EUR so amounts are never mixed across currencies.
-- Tolerance: a difference below 0.1% of the legacy amount is ok, with a floor of 0.01 for small amounts.

with

legacy as (
    select
        coalesce(level_2, '<null>') as budget_level_2,
        coalesce(sum(amount), 0)::float8 as legacy_amount
    from gold.transactions_mart
    where currency = 'EUR'
    group by 1
),

current_side as (
    select
        coalesce(budget_level_2, '<null>') as budget_level_2,
        coalesce(sum(amount), 0)::float8 as current_amount
    from {{ ref('fct_trx__transactions_enriched_daily') }}
    where currency = 'EUR'
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
            <= greatest(0.01, 0.001 * abs(coalesce(l.legacy_amount, 0))) then 'ok'
        else 'mismatch'
    end as status
from legacy as l
full outer join current_side as c on l.budget_level_2 = c.budget_level_2
order by 1
