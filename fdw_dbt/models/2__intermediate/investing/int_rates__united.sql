{{ config(
    tags=['refactored', 'main', 'rated']
) }}

select
    p.rate_id,
    p.asset,
    p.exchange_asset,
    p.calendar_date,
    max(p.exchange_rate) as exchange_rate
from (
    select rate_id, asset, exchange_asset, calendar_date, exchange_rate from {{ref("int_rates__fiat_combinations")}}
    union all
    select rate_id, asset, exchange_asset, calendar_date, exchange_rate from {{ref("stg_investing__rates")}}
) p
where p.exchange_rate > 0 
group by
    p.rate_id,
    p.asset,
    p.exchange_asset,
    p.calendar_date