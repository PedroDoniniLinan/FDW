{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    unique_key='fiat_transaction_id',
    event_time='calendar_date',
    begin='2019-01-01',
    batch_size='month',
    lookback=2,
    on_schema_change=get_on_schema_change(),
    tags=['refactored', 'main', 'rated']
) }}

with

raw_fiat_converted_transactions as (
    select
        fiat_transaction_id,
        transaction_id,
        calendar_date,
        transaction_type,
        transaction_description,
        account,
        category,
        asset,
        currency,
        units,
        exchange_rate,
        amount
    from {{ ref("fct_trx__cashflow_fiat_daily") }}
),

raw_dod_gains as (
    select fiat_transaction_id, calendar_date, account, asset, currency, amount
    from {{ ref("int_trx__gains_dod", event_time='calendar_date') }}
),

raw_intraday_gains as (
    select fiat_transaction_id, calendar_date, account, asset, currency, amount
    from {{ ref("int_trx__gains_intraday") }}
),

fiat_converted_transactions as (
    select
        fiat_transaction_id,
        transaction_id,
        calendar_date,
        transaction_type,
        transaction_description,
        account,
        category,
        asset,
        currency,
        units,
        exchange_rate,
        amount
    from raw_fiat_converted_transactions
),

dod_gains_transactions as (
    select
        fiat_transaction_id,
        fiat_transaction_id as transaction_id,
        calendar_date,
        'Income' as transaction_type,
        asset || '/' || currency as transaction_description,
        account,
        asset as category,
        asset,
        currency,
        amount as units,
        1 as exchange_rate,
        amount
    from raw_dod_gains
),

intraday_gains_transactions as (
    select
        fiat_transaction_id,
        fiat_transaction_id as transaction_id,
        calendar_date,
        'Income' as transaction_type,
        asset || '/' || currency || '/intra' as transaction_description,
        account,
        asset as category,
        asset,
        currency,
        amount as units,
        1 as exchange_rate,
        amount
    from raw_intraday_gains
),

final as (
    select * from fiat_converted_transactions
    union all
    select * from dod_gains_transactions
    union all
    select * from intraday_gains_transactions
)

select * from final
