-- Test: amount per account, EUR only (sum of amount), legacy vs current.
-- Dimension mapping: account -> account. Filtered to currency EUR so amounts are never mixed across currencies.
-- Tolerance: a difference below 0.1% of the legacy amount is ok, with a floor of 0.01 for small amounts.

with

legacy as (
    select
        coalesce(account, '<null>') as account,
        coalesce(sum(amount), 0)::float8 as legacy_amount
    from gold.transactions_mart
    where currency = 'EUR'
    group by 1
),

current_side as (
    select
        coalesce(account, '<null>') as account,
        coalesce(sum(amount), 0)::float8 as current_amount
    from "prod"."gold"."fct_trx__transactions_enriched_daily"
    where currency = 'EUR'
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
            <= greatest(0.01, 0.001 * abs(coalesce(l.legacy_amount, 0))) then 'ok'
        else 'mismatch'
    end as status
from legacy as l
full outer join current_side as c on l.account = c.account
order by 1