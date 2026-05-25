{{ config( materialized='table') }}

select 
    asset as rounding_asset,
    exchange_rate as max_exchange_rate,
    (case
        when asset in ('BTC','ETH') then 6
        when asset ~* 'brl|eur|usd|nubank' then 0
        when exchange_rate < 1 then -2
        when exchange_rate::integer > 0 then log(10, exchange_rate::integer) 
        else 0 
    end)::integer + 2 as round_num
from (
    select
        asset,
        max(exchange_rate) as exchange_rate
    from {{ ref("stg_investing__rates") }}
    group by 1
) t