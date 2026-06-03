{{ config(
    tags=['refactored', 'balance_validation', 'main', 'rated']
) }}

{%- set src = source('bronze', 'prices') -%}

select
    ticker as asset,
    currency as exchange_asset,
    calendar_date,
    md5(ticker || currency || calendar_date)::uuid as rate_id,
    round(price::numeric, 7) as exchange_rate
from {{ src }}
