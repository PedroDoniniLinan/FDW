-- Test: balance per month and label, EUR (sum of monthly balance), legacy vs current.
-- Dimension mapping: label -> label. Projections carry no currency column and both sides are EUR, so the currency column is the literal 'EUR' and no currency filter is applied.
-- Legacy goal rows (Retirement, House, Car goal) are excluded: the current model does not produce them, so they are a known gap shown in the per-label test.
-- Month key: current actuals are dated on the last day of the month, legacy actuals on the first, so both sides are truncated to the first day of the month.
-- Tolerance: a difference below 0.1% of the legacy amount is ok, with a floor of 1 for small amounts.

with

legacy as (
    select
        date_trunc('month', calendar_date)::date as period,
        coalesce(label, '<null>') as label,
        'EUR'::text as currency,
        coalesce(sum(balance), 0)::float8 as legacy_amount
    from silver.int_balance_projections_monthly
    where label not in ('Retirement goal', 'House goal', 'Car goal')
    group by 1, 2, 3
),

current_side as (
    select
        date_trunc('month', calendar_date)::date as period,
        coalesce(label, '<null>') as label,
        'EUR'::text as currency,
        coalesce(sum(balance), 0)::float8 as current_amount
    from "prod"."gold"."fct_prj__balances_projected_monthly"
    group by 1, 2, 3
)

select
    coalesce(l.period, c.period) as period,
    coalesce(l.label, c.label) as label,
    coalesce(l.currency, c.currency) as currency,
    round(l.legacy_amount::numeric, 2) as legacy_amount,
    round(c.current_amount::numeric, 2) as current_amount,
    round((coalesce(c.current_amount, 0) - coalesce(l.legacy_amount, 0))::numeric, 2) as amount_diff,
    case
        when l.period is null then 'missing_in_legacy'
        when c.period is null then 'missing_in_current'
        when abs(coalesce(c.current_amount, 0) - coalesce(l.legacy_amount, 0))
            <= greatest(1, 0.001 * abs(coalesce(l.legacy_amount, 0))) then 'ok'
        else 'mismatch'
    end as status
from legacy as l
full outer join current_side as c
    on l.period = c.period and l.label = c.label and l.currency = c.currency
order by 1, 2, 3