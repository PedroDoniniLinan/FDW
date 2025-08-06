{# {{ config(schema='gold', materialized='view') }}

select 
    category,
    date_trunc('month', calendar_date)::date as calendar_month,
    sum(pnl) over (partition by category, date_trunc('month', calendar_date)) as month_pnl,
    sum(sale_value) over (partition by category, date_trunc('month', calendar_date)) as month_value,
    sum(pnl) over (partition by ticker) as asset_year_pnl,
    sum(pnl) over (partition by category) as cat_year_pnl,
    ticker,
    calendar_date,
    pnl,
    net_amount,
    avg_price,
    sale_price,
    applied_value,
    sale_value,
    currency,
    taxable_currency
from {{ref("taxes_pnl_mart")}}
where currency != 'BRL'
-- and category = 'Fixed income'
-- and category in ('BDR')
and abs(pnl) > 80
order by category, calendar_date, ticker #}