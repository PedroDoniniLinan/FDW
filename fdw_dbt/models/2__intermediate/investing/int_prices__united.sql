-- Prices + Conversions between fiats

select
    p.ticker,
    p.currency,
    p.calendar_date,
    max(p.price) as price
from (
    select price_id, ticker, currency, calendar_date, price from {{ref("int_prices__fiat_combinations")}}
    union all
    select price_id, ticker, currency, calendar_date, price from {{ref("stg_investing__prices")}}
) p
where p.price > 0 
group by
    p.ticker,
    p.currency,
    p.calendar_date