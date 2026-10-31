{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    unique_key='fiat_transaction_id',
    event_time='calendar_date',
    begin='2019-01-01',
    batch_size='month',
    lookback=2,
    tags=['refactored', 'categories', 'main', 'mart', 'rated']
) }}

with

transactions as (
    select
        fiat_transaction_id,
        transaction_id,
        calendar_date,
        transaction_description,
        asset,
        currency,
        transaction_type,
        category,
        account,
        units,
        exchange_rate,
        amount
    from {{ ref("fct_trx__transactions_fiat_daily") }}
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
        t.fiat_transaction_id,
        t.transaction_id,
        t.calendar_date,
        t.transaction_description,
        t.asset,
        t.currency,
        t.transaction_type,
        t.category,
        c.financial_level_1,
        c.financial_level_2,
        c.budget_level_1,
        c.budget_level_2,
        c.budget_level_3,
        t.account,
        a.account_country,
        a.budget_level as account_budget_level,
        t.units,
        t.exchange_rate,
        t.amount
    from transactions as t
    left join categories as c on (
        t.category = c.category
        and (t.transaction_type = c.transaction_type or t.transaction_type in ('Exchange', 'Transfer'))
    )
    left join accounts as a on (t.account = a.account)
),

final as (
    select
        fiat_transaction_id,
        transaction_id,
        calendar_date,
        transaction_description,
        asset,
        currency,
        transaction_type,
        category,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        account,
        account_country,
        account_budget_level,
        units,
        exchange_rate,
        amount
    from enriched
)

select * from final
