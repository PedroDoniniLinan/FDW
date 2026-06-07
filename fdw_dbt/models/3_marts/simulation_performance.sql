{{ config(schema='gold', materialized='view') }}

select a.*,
    s.label||'/'||a.set::text||'/'||method as breakdown,
    -- set::text||'/'||method||'/'||start_date::text as breakdown,
    capital_gain/balance as performance
from {{source('gold', 'allocation_simulations')}} a
left join {{ref("set_labels")}} s on (a.set = s.set)
-- where start_date = '2022-01-01'
-- and method = 'monthly rebalance'
-- and a.set = 6