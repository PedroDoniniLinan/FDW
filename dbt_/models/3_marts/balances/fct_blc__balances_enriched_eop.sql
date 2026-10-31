{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    unique_key='grain_id',
    event_time='calendar_date',
    begin='2019-01-01',
    batch_size='month',
    lookback=2,
    tags=['refactored', 'categories', 'main', 'mart', 'rated']
) }}

{%- set time_grain = ['day', 'week', 'month', 'quarter', 'year'] -%}

-- THIS MODEL DOESNOT MATCH THE UPSTREAM
-- PLEASE CHECK NEGATIVE BAALNCES

with

balances as (
    select
        balance_id,
        calendar_date,
        is_end_of_period,
        currency,
        account,
        account_country,
        account_ownership,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        balance
    from {{ ref("fct_blc__balances_enriched_daily") }}
),

unioned as (
    {% for t in time_grain %}
    select
        md5(balance_id::text || '{{ t }}')::uuid as grain_id,
        balance_id,
        {%- if t in ['day', 'week', 'month', 'year'] %}
        (date_trunc('{{ t }}', calendar_date)
            + interval '1 {{ t }}' - interval '1 day')::date as calendar_date,{% endif %}
        {%- if t in ['quarter'] %}
        (date_trunc('{{ t }}', calendar_date)
            + interval '3 month' - interval '1 day')::date as calendar_date,{% endif %}
        '{{ t }}' as time_grain,
        currency,
        account,
        account_country,
        account_ownership,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        balance
    from balances
    where is_end_of_period ~* '{{ t }}'
    and balance > 0
    {%- if not loop.last %}union all{% endif %}{% endfor %}
),

final as (
    select
        grain_id,
        balance_id,
        calendar_date,
        time_grain,
        currency,
        account,
        account_country,
        account_ownership,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        balance
    from unioned
)

select * from final
