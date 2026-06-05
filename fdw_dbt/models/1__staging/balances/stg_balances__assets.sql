{{ config(
    tags=['refactored', 'balance_validation', 'main']
) }}

{%- set src = source('bronze', 'balances') -%}

select
    asset_id,
    asset
from (
    select distinct
        currency as asset,
        md5(currency)::uuid as asset_id
    from {{ src }}
)
