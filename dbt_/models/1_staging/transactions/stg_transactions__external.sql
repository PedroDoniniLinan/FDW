{{ config(
    tags=['refactored', 'balance_validation', 'main']
) }}

with external_transactions as (
    select
        id,
        transaction_type,
        tag,
        amount,
        account,
        calendar_date,
        subcategory,
        currency,
        count_to_balance
    from {{ source('bronze', 'external_transactions') }}
    where amount != 0
),

final as (
    select
        md5(id::text || '_' || lower(transaction_type))::uuid as transaction_id,
        id as source_transaction_id,
        transaction_type,
        tag as transaction_description,
        amount as units,
        account,
        calendar_date,
        subcategory as category,
        currency as asset,
        count_to_balance
    from external_transactions
)

select * from final
