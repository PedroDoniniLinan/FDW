{{ config(schema='silver', materialized='view') }}
{% set agg = ['level_3', 'level_2', 'portfolio'] %}
{# {% set benchmarks = ['SPY'] %} #}
{% set benchmarks = ['SPY', 'TD SELIC', 'EUR212', 'BTC', 'MS'] %}

{% for a in agg %}
select 
    currency,
    {% if a in ['portfolio'] %}
    '(A) Portfolio' as field,
    level_3||' (benchmark)' as breakdown,{% endif %}
    {% if a not in ['portfolio'] %}
    case when '{{ a }}' = 'level_3' then '(C) ' when '{{ a }}' = 'level_2' then '(B) ' else '(D) ' end
    ||initcap(replace('{{ a }}', '_', ' ')) as field,
    level_3||' (benchmark)' as breakdown,{% endif %}
    calendar_date,
    0 as balance,
    0 as yield,
    performance,
    performance - 1 as yield_rate
from {{ ref("int_price_yields_monthly") }} y
where y.level_3 in ({% for b in benchmarks %}'{{ b }}'{% if not loop.last %}, {% endif %}{% endfor %})
{% if not loop.last %}union all{% endif %}{% endfor %}