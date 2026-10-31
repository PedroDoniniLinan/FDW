{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    unique_key='balance_id',
    event_time='calendar_date',
    begin='2019-01-01',
    batch_size='month',
    lookback=2,
    tags=['refactored', 'categories', 'main', 'mart', 'rated']
) }}

with

balances as (
    select
        balance_id,
        calendar_date,
        is_end_of_period,
        asset,
        currency,
        account,
        balance
    from {{ ref("fct_blc__balances_daily") }}
),

categories as (
    select
        category,
        transaction_type,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3
    from {{ ref("dim_trx__categories") }}
),

accounts as (
    select account, account_country, budget_level
    from {{ ref("dim_account") }}
),

enriched as (
    select
        b.balance_id,
        b.calendar_date,
        b.is_end_of_period,
        b.asset,
        b.currency,
        b.account,
        a.account_country,
        a.budget_level as account_ownership,
        c.financial_level_1,
        c.financial_level_2,
        c.budget_level_1,
        c.budget_level_2,
        c.budget_level_3,
        b.balance
    from balances as b
    left join categories as c on (b.asset = c.category and c.transaction_type = 'Income')
    left join accounts as a on (b.account = a.account)
),

final as (
    select
        balance_id,
        calendar_date,
        is_end_of_period,
        asset,
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
    from enriched
)

select * from final
