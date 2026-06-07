{{ config(schema='silver', materialized='view') }}

-- Prices + Conversions between fiats

select
    p.ticker,
    p.currency,
    p.calendar_date,
    max(p.price) as price
from (
    select ticker, currency, calendar_date, price from {{source('bronze', 'prices')}}
    union all
    select ticker, currency, calendar_date, price from {{ref("src_fiat_to_fiat_prices")}}
) p
where p.price > 0 
group by
    p.ticker,
    p.currency,
    p.calendar_date