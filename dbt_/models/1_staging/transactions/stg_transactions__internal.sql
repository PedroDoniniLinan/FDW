{{ config(
    tags=['refactored', 'balance_validation', 'main']
) }}

with raw_transfers as (
    select
        id,
        amount,
        source_acc,
        destination_acc,
        calendar_date,
        currency
    from {{ source('bronze', 'transfers') }}
),

transfer_out as (
    select
        md5(id::text || '_tfo')::uuid as transaction_id,
        id as source_transaction_id,
        'Transfer' as transaction_type,
        source_acc || '->' || destination_acc as transaction_description,
        -amount as units,
        source_acc as account,
        calendar_date,
        'Transfer out' as category,
        currency as asset,
        true as count_to_balance
    from raw_transfers
),

transfer_in as (
    select
        md5(id::text || '_tfi')::uuid as transaction_id,
        id as source_transaction_id,
        'Transfer' as transaction_type,
        destination_acc || '<-' || source_acc as transaction_description,
        amount as units,
        destination_acc as account,
        calendar_date,
        'Transfer in' as category,
        currency as asset,
        true as count_to_balance
    from raw_transfers
),

unioned_transfers as (
    select * from transfer_out
    union all
    select * from transfer_in
),

final as (
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
    from unioned_transfers
)

select * from final
