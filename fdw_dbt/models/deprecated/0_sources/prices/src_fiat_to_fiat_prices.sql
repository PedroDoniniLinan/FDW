{{ config(schema='bronze', materialized='table') }}

-- All possible conversions between fiat currencies

select
    ticker,
    currency,
    calendar_date,
    round(price::numeric, 7) as price
from {{source('bronze', 'prices')}}
where ticker in {{fiat_currencies()}}
    and ticker != currency
union all
select
    currency as ticker,
    ticker as currency,
    calendar_date,
    round(1/price::numeric, 7) as price
from {{source('bronze', 'prices')}}
where ticker in {{fiat_currencies()}}
    and ticker != currency
union all
select distinct
    ticker,
    ticker as currency,
    calendar_date,
    1 as price
from {{source('bronze', 'prices')}}
where ticker in {{fiat_currencies()}}
