{{ config(
    tags=['refactored', 'balance_validation']
) }}

with raw_balances as (
    select
        id,
        account,
        currency,
        calendar_date,
        amount
    from {{ source('bronze', 'balances') }}
),

ranked as (
    select
        id as extract_id,
        account,
        currency as asset,
        calendar_date,
        amount as units,
        row_number() over (partition by account, currency, calendar_date order by id desc) as rn
    from raw_balances
),

final as (
    select
        extract_id,
        account,
        asset,
        calendar_date,
        units
    from ranked
    where rn = 1
)

select * from final
