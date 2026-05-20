{%- set src = source('bronze', 'prices') -%}

select
    md5(ticker || currency || calendar_date)::uuid as rate_id,
    ticker as asset,
    currency as exchange_asset,
    calendar_date,
    round(price::numeric, 7) as exchange_rate
from {{ src }}
