{%- set lookback_days = var('lookback_days_eop', 30) -%}

{%- set config_dict = {
    'materialized': 'incremental',
    'unique_key': 'grain_id',
    'incremental_strategy': 'merge',
    'tags': ['refactored', 'categories', 'main', 'mart', 'rated']
} -%}

{%- if is_incremental() -%}
    {%- do config_dict.update({'incremental_predicates': [
        "DBT_INTERNAL_DEST.calendar_date > " ~ get_latest_date(this, 'calendar_date', lookback_days, 'day')
    ]}) -%}
{%- endif -%}

{{ config(**config_dict) }}

{%- set time_grain = ['day', 'week', 'month', 'quarter', 'year'] -%}

-- THIS MODEL DOESNOT MATCH THE UPSTREAM
-- PLEASE CHECK NEGATIVE BAALNCES

{% for t in time_grain %}
select
    md5(ad.balance_id::text || '{{t}}')::uuid as grain_id,
    ad.balance_id,
    {%- if t in ['day', 'week', 'month', 'year'] %}
    (date_trunc('{{t}}', ad.calendar_date) + interval '1 {{t}}' - interval '1 day')::date as calendar_date,{% endif %}
    {%- if t in ['quarter'] %}
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
{% if is_incremental() -%}
and ad.calendar_date > {{ get_latest_date(this, 'calendar_date', lookback_days, 'days') }}
{% endif %}
{%- if not loop.last %}union all{% endif %}{% endfor %}