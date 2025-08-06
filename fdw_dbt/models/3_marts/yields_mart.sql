{{ config(schema='gold', materialized='view') }}

select
    'Non-cumulative' as yield_type,
    calendar_date as start_date,
    * 
from {{ ref("int_yields_agg_time_grains") }}
union all
select
    'Cumulative' as yield_type,
    * 
from {{ ref("int_yield_agg_cum") }}