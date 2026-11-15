-- Test: balance per year and fiat currency (sum of daily balance), legacy vs current. Rows in currency 'Original' are excluded; a separate per-asset test covers them when requested.
-- Summing daily balances over a year is a checksum for comparing both sides, not a meaningful annual total.
-- Tolerance: a difference below 0.1% of the legacy amount is ok, with a floor of 1 for small amounts.

with

legacy as (
    select
        date_trunc('year', calendar_date)::date as period,
        currency,
        coalesce(sum(balance), 0)::float8 as legacy_amount
    from gold.balances_mart
    where currency <> 'Original'
    group by 1, 2
),

current_side as (
    select
        date_trunc('year', calendar_date)::date as period,
        currency,
        coalesce(sum(balance), 0)::float8 as current_amount
    from {{ ref('fct_blc__balances_enriched_daily') }}
    where currency <> 'Original'
    group by 1, 2
)

select
    coalesce(l.period, c.period) as period,
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
    on l.period = c.period and l.currency = c.currency
order by 1, 2
