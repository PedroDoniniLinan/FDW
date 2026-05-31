{% set time_grain = ['day', 'week', 'month', 'quarter', 'year'] %}

-- THIS MODEL DOESNOT MATCH THE UPSTREAM
-- PLEASE CHECK NEGATIVE BAALNCES

{% for t in time_grain %}
select
    md5(ad.balance_id::text || '{{t}}')::uuid as grain_id,
    ad.balance_id,
    {% if t in ['day', 'week', 'month', 'year'] %}
    (date_trunc('{{t}}', ad.calendar_date) + interval '1 {{t}}' - interval '1 day')::date as calendar_date,{% endif %}
    {% if t in ['quarter'] %}
    (date_trunc('{{t}}', ad.calendar_date) + interval '3 month' - interval '1 day')::date as calendar_date,{% endif %}
    '{{t}}' as time_grain,
    ad.currency,
    ad.account,
    ad.account_country,
    ad.account_ownership,
    ad.financial_level_1,
    ad.financial_level_2,
    ad.budget_level_1,
    ad.budget_level_2,
    ad.budget_level_3,
    ad.balance
from {{ref("fct_balances_enriched")}} ad
where is_end_of_period ~* '{{t}}'
and balance > 0
{% if not loop.last %}union all{% endif %}{% endfor %}