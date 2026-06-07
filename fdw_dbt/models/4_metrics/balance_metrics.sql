{{ config(schema='gold', materialized='table') }}
{% set time_grain = ['day', 'week', 'month', 'quarter', 'year'] %}

-- THIS MODEL DOESNOT MATCH THE UPSTREAM
-- PLEASE CHECK NEGATIVE BAALNCES

{% for t in time_grain %}
select
    {% if t in ['day', 'week', 'month', 'year'] %}
    (date_trunc('{{t}}', ad.calendar_date) + interval '1 {{t}}' - interval '1 day')::date as calendar_date,{% endif %}
    {% if t in ['quarter'] %}
    (date_trunc('{{t}}', ad.calendar_date) + interval '3 month' - interval '1 day')::date as calendar_date,{% endif %}
    '{{t}}' as time_grain,
    ad.currency,
    ad.original_currency,
    ad.account,
    ad.account_country,
    ad.account_budget_level,
    ad.level_1,
    ad.level_2,
    ad.level_3,
    ad.source,
    ad.balance
from {{ref("balances_mart")}} ad
where is_end_of_period ~* '{{t}}'
and balance > 0
{% if not loop.last %}union all{% endif %}{% endfor %}