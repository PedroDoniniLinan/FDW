{{ config(schema='silver', materialized='table') }}

select
    currency,
    field,
    breakdown,
    (date_trunc('month', calendar_date) + interval '1 month' - interval '1 day')::date as calendar_date,
    avg(balance) as balance,
    sum(yield) as yield,
    {{ prod('1 + yield_rate') }} as performance,
    {{ prod('1 + yield_rate') }} - 1 as yield_rate
from {{ ref("int_yields_agg") }}
where (1 + yield_rate) > 0
group by
    currency,
    field,
    breakdown,
    (date_trunc('month', calendar_date) + interval '1 month' - interval '1 day')::date