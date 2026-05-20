{{ config(materialized='table') }}

{%- set src = ref("int_rates__interpolated_daily") -%}

with

    fiat_converted as (
        select
            p.calendar_date,
            p.is_end_of_period,
            p.asset,
            p.exchange_asset as base_exchange_asset,
            p.exchange_rate as base_exchange_rate,
            pf.exchange_asset as currency,
            pf.exchange_rate as currency_exchange_rate,
            case 
                when p.asset = pf.exchange_asset then 1 
                when p.exchange_rate < 0.01 then (p.exchange_rate*pf.exchange_rate)
                else (p.exchange_rate*pf.exchange_rate)
                {# else (round(p.exchange_rate::numeric, 4)*round(pf.exchange_rate::numeric, 4)) #}
            end as exchange_rate,
            row_number() over (
                partition by p.asset, pf.exchange_asset, p.calendar_date 
                order by (p.exchange_asset = pf.exchange_asset) desc, p.exchange_rate) as rn
        from {{ src }} p
            left join {{ src }} pf on (
                p.exchange_asset = pf.asset
                and p.calendar_date = pf.calendar_date
                and pf.exchange_asset in {{fiat_currencies()}}
            )
    )

select
    md5(asset || currency || calendar_date)::uuid as rate_id,
    calendar_date,
    is_end_of_period,
    asset,
    currency,
    max(exchange_rate) as exchange_rate
from fiat_converted
where rn = 1
and calendar_date is not null
group by
    asset,
    currency,
    calendar_date,
    is_end_of_period