{{ config(
    tags=['refactored', 'balance_validation', 'main']
) }}

with

raw_exchange_transactions as (
    select
        transaction_id,
        source_transaction_id,
        transaction_type,
        transaction_description,
        units,
        account,
        calendar_date,
        category,
        asset,
        count_to_balance
    from {{ ref("stg_transactions__exchanges") }}
),

raw_internal_transactions as (
    select
        transaction_id,
        source_transaction_id,
        transaction_type,
        transaction_description,
        units,
        account,
        calendar_date,
        category,
        asset,
        count_to_balance
    from {{ ref("stg_transactions__internal") }}
),

raw_external_transactions as (
    select
        transaction_id,
        source_transaction_id,
        transaction_type,
        transaction_description,
        units,
        account,
        calendar_date,
        category,
        asset,
        count_to_balance
    from {{ ref("stg_transactions__external") }}
),

raw_asset_rounding as (
    select rounding_asset, round_num
    from {{ ref('int_com__asset_rounding') }}
),

exchange_transactions as (
    select
        transaction_id,
        source_transaction_id,
        transaction_type,
        transaction_description,
        units,
        account,
        calendar_date,
        category,
        asset,
        count_to_balance
    from raw_exchange_transactions
),

internal_transactions as (
    select
        transaction_id,
        source_transaction_id,
        transaction_type,
        transaction_description,
        units,
        account,
        calendar_date,
        category,
        asset,
        count_to_balance
    from raw_internal_transactions
),

external_transactions as (
    select
        transaction_id,
        source_transaction_id,
        transaction_type,
        transaction_description,
        units,
        account,
        calendar_date,
        category,
        asset,
        count_to_balance
    from raw_external_transactions
),

unioned_transactions as (
    select * from exchange_transactions
    union all
    select * from internal_transactions
    union all
    select * from external_transactions
),

rounding as (
    select
        l.transaction_id,
        l.source_transaction_id,
        l.transaction_type,
        l.transaction_description,
        l.account,
        l.calendar_date,
        l.category,
        l.asset,
        l.count_to_balance,
        round(
            l.units::numeric,
            r.round_num
        ) as units
    from unioned_transactions as l
    left join raw_asset_rounding as r on (l.asset = r.rounding_asset)
    where l.units is not null
),

final as (
    select
        transaction_id,
        source_transaction_id,
        transaction_type,
        transaction_description,
        account,
        calendar_date,
        category,
        asset,
        count_to_balance,
        units
    from rounding
)

select * from final
