{{ config(
    tags=['refactored', 'balance_validation', 'main']
) }}

{%- set src = source('bronze', 'balances') -%}

select distinct
    md5(currency)::uuid as asset_id,
    currency as asset
from {{ src }}
