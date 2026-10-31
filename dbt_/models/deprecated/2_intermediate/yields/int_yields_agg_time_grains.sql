{{ config(schema='silver', materialized='table') }}
{% set time_grain = ['month', 'quarter', 'year', 'all time'] %}

{% for t in time_grain %}
select 
    currency,
    {% if t in ['month', 'year'] %}
    (date_trunc('{{t}}', calendar_date))::date as calendar_date,{% endif %}
    {% if t in ['quarter'] %}
    (date_trunc('{{t}}', calendar_date))::date as calendar_date,{% endif %}
    {% if t in ['all time'] %}
    current_date::date as calendar_date,{% endif %}
    '{{t}}' as time_grain,
    field,
    breakdown,
    sum(yield) as yield,
    {{ prod('1 + yield_rate') }} as performance,
    {{ prod('1 + yield_rate') }} - 1 as yield_rate
from (
    select * from {{ ref("int_yields_agg_monthly") }}
    union all
    select * from {{ ref("int_benchmark_yields_agg_monthly") }}
) t
group by 
    currency,
    2,
    time_grain,
    field,
    breakdown
{% if not loop.last %}union all{% endif %}{% endfor %}