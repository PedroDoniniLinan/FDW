{{ config(schema='gold', materialized='table') }}

select
    y.yield_type,
    y.start_date,
    y.currency,
    y.calendar_date,
    y.time_grain,
    y.field,
    case 
        when field  ~* 'port' then 'Portfolio'
        when field  ~* '2' then breakdown
        else ic.level_2
    end as level_2, 
    y.breakdown,
    y.yield,
    y.performance,
    y.yield_rate
from {{ ref("yields_mart") }} y
    left join (
        select distinct level_2, level_3 
        from {{ ref("income_categories") }}
    ) ic on (y.breakdown = ic.level_3)