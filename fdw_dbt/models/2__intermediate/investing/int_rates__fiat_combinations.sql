{{ config(
    tags=['refactored', 'main', 'rated']
) }}

{%- set src = ref('stg_investing__rates') -%}
{%- set fiat_currencies = fiat_currencies() -%}

select
    rate_id,
    asset,
    exchange_asset,
    calendar_date,
    exchange_rate
from {{ src }}
where asset in {{ fiat_currencies }}
    and asset != exchange_asset
union all
select
    md5(exchange_asset || asset || calendar_date)::uuid as rate_id,
    exchange_asset as asset,
    asset as exchange_asset,
    calendar_date,
    round(1/exchange_rate::numeric, 7) as exchange_rate
from {{ src }}
where asset in {{ fiat_currencies }}
    and asset != exchange_asset
union all
select distinct
    md5(asset || asset || calendar_date)::uuid as rate_id,
    asset,
    asset as exchange_asset,
    calendar_date,
    1 as exchange_rate
from {{ src }}
where asset in {{ fiat_currencies }}
