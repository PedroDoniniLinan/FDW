{{ config(schema='gold', materialized='view') }}

select *
from {{ref("taxes_assets_mart")}}
where currency = 'BRL'