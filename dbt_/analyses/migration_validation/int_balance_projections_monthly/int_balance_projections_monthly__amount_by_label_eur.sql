-- Test: balance per label, EUR only (sum of monthly balance), legacy vs current.
-- Dimension mapping: label -> label (Projection 0-4, Actuals, and the goal labels). Projections carry no currency column and both sides are EUR, so no currency filter is applied.
-- Goal labels (Retirement, House, Car goal) exist only on the legacy side: they show as missing_in_current, a known gap in the replacement.
-- Summing monthly balances is a checksum for comparing both sides, not a meaningful total.
-- Tolerance: a difference below 0.1% of the legacy amount is ok, with a floor of 1 for small amounts.

with

legacy as (
    select
        coalesce(label, '<null>') as label,
        coalesce(sum(balance), 0)::float8 as legacy_amount
    from silver.int_balance_projections_monthly
    group by 1
),

current_side as (
    select
        coalesce(label, '<null>') as label,
        coalesce(sum(balance), 0)::float8 as current_amount
    from {{ ref('fct_prj__balances_projected_monthly') }}
    group by 1
)

select
    coalesce(l.label, c.label) as label,
    round(l.legacy_amount::numeric, 2) as legacy_amount,
    round(c.current_amount::numeric, 2) as current_amount,
    round((coalesce(c.current_amount, 0) - coalesce(l.legacy_amount, 0))::numeric, 2) as amount_diff,
    case
        when l.label is null then 'missing_in_legacy'
        when c.label is null then 'missing_in_current'
        when abs(coalesce(c.current_amount, 0) - coalesce(l.legacy_amount, 0))
            <= greatest(1, 0.001 * abs(coalesce(l.legacy_amount, 0))) then 'ok'
        else 'mismatch'
    end as status
from legacy as l
full outer join current_side as c on l.label = c.label
order by 1
