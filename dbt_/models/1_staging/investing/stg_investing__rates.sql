{{ config(
    tags=['refactored', 'balance_validation', 'main', 'rated']
) }}

with prices as (
    select
        ticker,
        currency,
        calendar_date,
        price
    from {{ source('bronze', 'prices') }}
),

final as (
    select
        ticker as asset,
        currency as exchange_asset,
        calendar_date,
        md5(ticker || currency || calendar_date)::uuid as rate_id,
        round(price::numeric, 7) as exchange_rate
    from prices
)

select * from final
