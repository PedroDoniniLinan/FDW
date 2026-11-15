-- Test: balance on the last calendar_date of each account, EUR only (sum of balance on that date), legacy vs current.
-- Dimension mapping: account -> account. Filtered to currency EUR so amounts are never mixed across currencies.
-- Each side uses its own last date per account, so a side that ends earlier shows as a mismatch.
-- Tolerance: a difference below 0.1% of the legacy amount is ok, with a floor of 1 for small amounts.

with

legacy_dated as (
    select
        coalesce(account, '<null>') as account,
        calendar_date,
        balance,
        max(calendar_date) over (partition by coalesce(account, '<null>')) as last_date
    from gold.balances_mart
    where currency = 'EUR'
),

legacy as (
    select
        account,
        coalesce(sum(balance), 0)::float8 as legacy_amount
    from legacy_dated
    where calendar_date = last_date
    group by 1
),

current_dated as (
    select
        coalesce(account, '<null>') as account,
        calendar_date,
        balance,
        max(calendar_date) over (partition by coalesce(account, '<null>')) as last_date
    from {{ ref('fct_blc__balances_enriched_daily') }}
    where currency = 'EUR'
),

current_side as (
    select
        account,
        coalesce(sum(balance), 0)::float8 as current_amount
    from current_dated
    where calendar_date = last_date
    group by 1
)

select
    coalesce(l.account, c.account) as account,
    round(l.legacy_amount::numeric, 2) as legacy_amount,
    round(c.current_amount::numeric, 2) as current_amount,
    round((coalesce(c.current_amount, 0) - coalesce(l.legacy_amount, 0))::numeric, 2) as amount_diff,
    case
        when l.account is null then 'missing_in_legacy'
        when c.account is null then 'missing_in_current'
        when abs(coalesce(c.current_amount, 0) - coalesce(l.legacy_amount, 0))
            <= greatest(1, 0.001 * abs(coalesce(l.legacy_amount, 0))) then 'ok'
        else 'mismatch'
    end as status
from legacy as l
full outer join current_side as c on l.account = c.account
order by 1
