{{ config(schema='silver', materialized='view') }}
{% set agg = ['level_3', 'level_2', 'portfolio'] %}
{# {% set agg = ['level_2'] %} #}

{% for a in agg %}
select 
    currency,
    calendar_date,
    {% if a in ['portfolio'] %}
    '(A) Portfolio' as field,
    'Portfolio' as breakdown,{% endif %}
    {% if a not in ['portfolio'] %}
    case when '{{ a }}' = 'level_3' then '(C) ' when '{{ a }}' = 'level_2' then '(B) ' else '(D) ' end
    ||initcap(replace('{{ a }}', '_', ' ')) as field,
    {{ a }} as breakdown,{% endif %}
    coalesce(sum(prev_balance), sum(balance)) as prev_balance,
    sum(balance) as balance,
    sum(yield) as yield,
    case 
        when round(coalesce(sum(prev_balance), sum(balance))::numeric, 0) > 0 then 
            (1 + sum(yield) / nullif(coalesce(sum(prev_balance), sum(balance)), 0)) 
        else 1 
    end as performance,
    case 
        when round(coalesce(sum(prev_balance), sum(balance))::numeric, 0) > 0 then 
            sum(yield) / nullif(coalesce(sum(prev_balance), sum(balance)), 0) 
        else 0 
    end as yield_rate
from {{ ref("int_yields_daily") }}
{# where level_2 ~* 'Volatile' #}
group by 
    currency,
    2,
    field,
    breakdown
{% if not loop.last %}union all{% endif %}{% endfor %}