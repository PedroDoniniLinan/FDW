{%- set src = source('bronze', 'prices') -%}

select
    id as price_id,
    ticker,
    currency,
    calendar_date,
    round(price::numeric, 7) as price
from {{ src }}
