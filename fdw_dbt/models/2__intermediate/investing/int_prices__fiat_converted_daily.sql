{{ config(materialized='table') }}

{%- set src = ref("int_prices__interpolated_daily") -%}

with

    fiat_converted as (
        select
            p.ticker,
            p.currency as original_currency,
            pf.currency,
            p.calendar_date,
            p.is_end_of_period,
            p.price as original_price,
            pf.price as currency_price,
            case 
                when p.ticker = pf.currency then 1 
                when p.price < 0.01 then (p.price*pf.price)
                else (p.price*pf.price)
                {# else (round(p.price::numeric, 4)*round(pf.price::numeric, 4)) #}
            end as price,
            row_number() over (partition by p.ticker, pf.currency, p.calendar_date order by (p.currency = pf.currency) desc, p.price) as rn
        from {{ src }} p
            left join {{ src }} pf on (
                p.currency = pf.ticker
                and p.calendar_date = pf.calendar_date
                and pf.currency in {{fiat_currencies()}}
            )
    )

select
    p.ticker,
    p.currency,
    p.calendar_date,
    p.is_end_of_period,
    max(p.original_price) as original_price,
    max(p.currency_price) as currency_price,
    max(p.price) as price
    {# max(round(p.price::numeric, 4)) as price #}
from fiat_converted p
where rn = 1
and calendar_date is not null
group by
    p.ticker,
    -- p.currency,
    p.currency,
    p.calendar_date,
    p.is_end_of_period
-- order by currency desc, calendar_date desc