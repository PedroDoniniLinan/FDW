{{ config(materialized='table') }}

{%- set src = ref('stg_investing__prices') -%}
{%- set fiat_currencies = fiat_currencies() -%}

select
    price_id,
    ticker,
    currency,
    calendar_date,
    price
from {{ src }}
where ticker in {{ fiat_currencies }}
    and ticker != currency
union all
select
    md5(price_id::text||'_ct')::uuid as price_id,
    currency as ticker,
    ticker as currency,
    calendar_date,
    round(1/price::numeric, 7) as price
from {{ src }}
where ticker in {{ fiat_currencies }}
    and ticker != currency
union all
select distinct
    md5(price_id::text||'_tt')::uuid as price_id,
    ticker,
    ticker as currency,
    calendar_date,
    1 as price
from {{ src }}
where ticker in {{ fiat_currencies }}
