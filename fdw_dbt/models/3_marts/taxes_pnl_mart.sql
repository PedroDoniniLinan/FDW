{# {{ config(schema='gold', materialized='view') }}

select 
    t.*,
    tc.taxable_currency,
    tc.category
from {{source('silver', 'taxes_pnl_raw')}} t
    inner join {{ref("taxes_categories")}} tc on (t.ticker = tc.ticker)
where date_trunc('year', calendar_date) = '2024-01-01'
order by ticker, calendar_date, net_amount, currency #}