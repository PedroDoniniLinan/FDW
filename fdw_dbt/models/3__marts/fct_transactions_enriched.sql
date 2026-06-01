{# {{ config(
    tags=['refactored', 'categories', 'main', 'mart', 'rated']
) }} #}

{{ config(
    materialized='incremental',
    unique_key='fiat_transaction_id',
    incremental_strategy='merge',
    tags=['refactored', 'categories', 'main', 'mart', 'rated']
) }}

{%- set lookback_days = var('lookback_days', 30) -%}

select
    t.fiat_transaction_id,
    t.transaction_id,
    t.calendar_date,
    t.transaction_description,
    t.asset,
    t.currency,
    t.transaction_type,
    t.category,
    tc.financial_level_1,
    tc.financial_level_2,
    tc.budget_level_1,
    tc.budget_level_2,
    tc.budget_level_3,
    t.account,
    ac.account_country,
    ac.budget_level as account_budget_level,
    t.units,
    t.exchange_rate,
    t.amount
from {{ref("int_transactions__all_with_gains")}} t
    left join {{ref("int_transaction_categories__united")}} tc on (
        t.category = tc.category 
        and (t.transaction_type = tc.transaction_type or t.transaction_type in ('Exchange', 'Transfer'))
        )
    left join {{ref("dim_account")}} ac on (t.account = ac.account)
{% if is_incremental() -%}
where calendar_date > (select max(calendar_date) - interval '{{ lookback_days }} days' from {{ this }})
{% endif %}