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

with

transactions as (
    select
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
        amount
    from {{ ref('fct_trx__transactions_enriched_daily') }}
    where transaction_type in ('Income', 'Expenses')
),

agg as (
    select
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
        md5(calendar_date::text || currency || transaction_type
            || financial_level_1 || financial_level_2 || budget_level_1
            || budget_level_2 || budget_level_3 || account || account_country) as grain_id,
        sum(amount) as amount,
        case when transaction_type = 'Expenses' then -sum(amount) else sum(amount) end as absolute_amount
    from transactions
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
),

final as (
    select
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
        account_country,
        amount,
        absolute_amount
    from agg
)

select * from final
