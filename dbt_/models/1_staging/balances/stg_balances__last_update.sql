{{ config(
    tags=['refactored', 'balance_validation', 'main']
) }}

with balances as (
    select max(calendar_date) as last_update
    from {{ source('bronze', 'balances') }}
),

final as (
    select last_update
    from balances
)

select * from final
