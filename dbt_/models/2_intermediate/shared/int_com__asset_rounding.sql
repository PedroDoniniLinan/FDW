{{ config(
    materialized='table',
    tags=['refactored', 'balance_validation', 'main']
) }}

with

import_rates as (
    select
        asset,
        exchange_rate
    from {{ ref("stg_investing__rates") }}
),

max_rates as (
    select
        asset,
        max(exchange_rate) as exchange_rate
    from import_rates
    group by 1
),

rounded_assets as (
    select
        asset as rounding_asset,
        exchange_rate as max_exchange_rate,
        (case
            when asset in ('BTC', 'ETH') then 6
            when asset ~* 'brl|eur|usd|nubank' then 0
            when exchange_rate < 1 then -2
            when exchange_rate::integer > 0 then log(10, exchange_rate::integer)
            else 0
        end)::integer + 2 as round_num
    from max_rates
),

final as (
    select
        rounding_asset,
        max_exchange_rate,
        round_num
    from rounded_assets
)

select * from final
