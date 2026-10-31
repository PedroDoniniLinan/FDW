{{ config(
    tags=['refactored', 'main', 'rated']
) }}

with

raw_fiat_rates as (
    select
        rate_id,
        asset,
        exchange_asset,
        calendar_date,
        exchange_rate
    from {{ ref("int_inv__rates_fiat_combinations_daily") }}
),

raw_investing_rates as (
    select
        rate_id,
        asset,
        exchange_asset,
        calendar_date,
        exchange_rate
    from {{ ref("stg_investing__rates") }}
),

unioned_rates as (
    select rate_id, asset, exchange_asset, calendar_date, exchange_rate from raw_fiat_rates
    union all
    select rate_id, asset, exchange_asset, calendar_date, exchange_rate from raw_investing_rates
),

aggregated_rates as (
    select
        rate_id,
        asset,
        exchange_asset,
        calendar_date,
        max(exchange_rate) as exchange_rate
    from unioned_rates
    where exchange_rate > 0
    group by rate_id, asset, exchange_asset, calendar_date
),

final as (
    select rate_id, asset, exchange_asset, calendar_date, exchange_rate
    from aggregated_rates
)

select * from final
