{{ config(
    materialized='incremental',
    unique_key='balance_id',
    incremental_strategy='merge',
    tags=['refactored', 'categories', 'main', 'mart', 'rated']
) }}

{%- set lookback_days = var('lookback_days', 30) -%}

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
from {{ref("int_balances__daily")}} ad
    left join {{ref("int_transaction_categories__united")}} tc on (ad.asset = tc.category and tc.transaction_type = 'Income')
    left join {{ref("dim_account")}} ac on (ad.account = ac.account)
{% if is_incremental() -%}
where ad.calendar_date > (select max(calendar_date) - interval '{{ lookback_days }} days' from {{ this }})
{% endif %}