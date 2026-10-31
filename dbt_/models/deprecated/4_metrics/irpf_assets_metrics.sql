{{ config(schema='gold', materialized='view', enabled=false) }}

select *
from {{ref("taxes_assets_mart")}}
where currency = 'BRL'