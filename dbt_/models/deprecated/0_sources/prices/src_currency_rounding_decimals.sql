{{ config(schema='bronze', materialized='table') }}

-- Decimal places for rounding by currency

select 
    ticker as rounding_currency,
    price as max_price,
    (case
        when ticker in ('BTC','ETH') then 6
        when ticker ~* 'brl|eur|usd|nubank' then 0
        when price < 1 then -2
        when price::integer > 0 then log(10, price::integer) 
        else 0 
    end)::integer + 2 as round_num
from (
    select
        ticker,
        max(price) as price
    from {{source('bronze', 'prices')}}
    group by 1
) t