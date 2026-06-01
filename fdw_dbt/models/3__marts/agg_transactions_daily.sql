{# {{ config(
    tags=['refactored', 'categories', 'main', 'mart', 'rated']
) }} #}

{{ config(
    materialized='incremental',
    unique_key='grain_id',
    incremental_strategy='merge',
    tags=['refactored', 'categories', 'main', 'mart', 'rated']
) }}

{%- set lookback_days = var('lookback_days', 30) -%}

select
    md5(calendar_date::text || currency || transaction_type || financial_level_1 || financial_level_2 || budget_level_1 
        || budget_level_2 || budget_level_3 || account || account_country) as grain_id,
    calendar_date,
    currency,
    transaction_type,
    financial_level_1,
    financial_level_2,
    budget_level_1,
    budget_level_2,
    budget_level_3,
    account,
    account_country,
    sum(amount) as amount,
    case when transaction_type = 'Expenses' then -sum(amount) else sum(amount) end as absolute_amount
from {{ref('fct_transactions_enriched')}}
where transaction_type in ('Income', 'Expenses')
{% if is_incremental() -%}
and calendar_date > (select max(calendar_date) - interval '{{ lookback_days }} days' from {{ this }})
{% endif -%}
group by
    grain_id,
    calendar_date,
    currency,
    transaction_type,
    financial_level_1,
    financial_level_2,
    budget_level_1,
    budget_level_2,
    budget_level_3,
    account,
    account_country