{%- set src = source('bronze', 'prices') -%}
{%- set fiat_currencies = fiat_currencies() -%}

{{ config(materialized='table') }}

select
    id||'_tc' as quote_id,
    ticker,
    currency,
    calendar_date,
    round(price::numeric, 7) as price
from {{ src }}
where ticker in {{ fiat_currencies }}
    and ticker != currency
union all
select
    id||'_ct' as quote_id,
    currency as ticker,
    ticker as currency,
    calendar_date,
    round(1/price::numeric, 7) as price
from {{ src }}
where ticker in {{ fiat_currencies }}
    and ticker != currency
union all
select distinct
    id||'_tt' as quote_id,
    ticker,
    ticker as currency,
    calendar_date,
    1 as price
from {{ src }}
where ticker in {{ fiat_currencies }}
