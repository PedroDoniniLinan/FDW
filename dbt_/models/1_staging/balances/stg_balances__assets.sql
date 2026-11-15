{{ config(
    tags=['refactored', 'balance_validation', 'main']
) }}

with balances as (
    select currency
    from {{ source('bronze', 'balances') }}
),

final as (
    select distinct
        currency as asset,
        md5(currency)::uuid as asset_id
    from balances
)

select * from final
