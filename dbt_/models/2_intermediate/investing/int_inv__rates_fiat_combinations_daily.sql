{{ config(
    tags=['refactored', 'main', 'rated']
) }}


with raw_rates as (
    select
        rate_id,
        asset,
        exchange_asset,
        calendar_date,
        exchange_rate
    from {{ ref('stg_investing__rates') }}
    where asset in {{ fiat_currencies() }}
),

direct_rates as (
    select
        rate_id,
        asset,
        exchange_asset,
        calendar_date,
        exchange_rate
    from raw_rates
    where asset != exchange_asset
),

inverse_rates as (
    select
        md5(exchange_asset || asset || calendar_date)::uuid as rate_id,
        exchange_asset as asset,
        asset as exchange_asset,
        calendar_date,
        round(1 / exchange_rate::numeric, 7) as exchange_rate
    from raw_rates
    where asset != exchange_asset
),

identity_rates as (
    select distinct
        md5(asset || asset || calendar_date)::uuid as rate_id,
        asset,
        asset as exchange_asset,
        calendar_date,
        1 as exchange_rate
    from raw_rates
),

final as (
    select rate_id, asset, exchange_asset, calendar_date, exchange_rate from direct_rates
    union all
    select rate_id, asset, exchange_asset, calendar_date, exchange_rate from inverse_rates
    union all
    select rate_id, asset, exchange_asset, calendar_date, exchange_rate from identity_rates
)

select * from final
