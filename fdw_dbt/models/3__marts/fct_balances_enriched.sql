{%- set lookback_days = var('lookback_days', 30) -%}

{%- set config_dict = {
    'materialized': 'incremental',
    'unique_key': 'balance_id',
    'incremental_strategy': 'merge',
    'tags': ['refactored', 'categories', 'main', 'mart', 'rated']
} -%}

{{ config(**config_dict) }}

select
    ad.balance_id,
    ad.calendar_date,
    ad.is_end_of_period,
    ad.asset,
    ad.currency,
    ad.account,
    ac.account_country,
    ac.budget_level as account_ownership,
    tc.financial_level_1,
    tc.financial_level_2,
    tc.budget_level_1,
    tc.budget_level_2,
    tc.budget_level_3,
    ad.balance
from {{ ref("int_balances__daily") }} as ad
    left join
        {{ ref("int_transaction_categories__united") }} as tc
    on (ad.asset = tc.category and tc.transaction_type = 'Income')
    left join {{ ref("dim_account") }} as ac on (ad.account = ac.account)
{% if is_incremental() -%}
where ad.calendar_date > {{ get_latest_date(this, 'calendar_date', lookback_days, 'days') }}
{% endif %}
