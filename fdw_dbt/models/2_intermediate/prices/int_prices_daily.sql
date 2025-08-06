{{ config(schema='silver', materialized='table') }}

with

    linear_regression as (
        select
            ticker,
            currency,
            calendar_date,
            (lead(calendar_date) over (partition by ticker, currency order by calendar_date) - interval '1 day')::date as next_calendar_date,
            price,
            lead(price) over (partition by ticker, currency order by calendar_date) as next_price,
            (lead(price) over (partition by ticker, currency order by calendar_date) - price)::numeric
                /(lead(calendar_date) over (partition by ticker, currency order by calendar_date) - calendar_date) as step
        from {{ref("stg_prices")}}
    ),

    daily_prices as (
        select
            l.ticker,
            l.currency,
            g.calendar_date,
            g.is_end_of_period,
            case    
                when l.price < 0.01 then (g.calendar_date - l.calendar_date) * coalesce(l.step, 0) + l.price
                else ((g.calendar_date - l.calendar_date) * coalesce(l.step, 0) + l.price) 
            end as price
        from linear_regression l
            left join {{ref('src_daily_grid')}} g on (
                g.calendar_date between l.calendar_date and coalesce(l.next_calendar_date, l.calendar_date)
            )
    ),

    all_fiat_currencies as (
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
        from daily_prices p
            left join daily_prices pf on (
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
from all_fiat_currencies p
where rn = 1
and calendar_date is not null
-- and ticker = 'NVD'
group by
    p.ticker,
    -- p.currency,
    p.currency,
    p.calendar_date,
    p.is_end_of_period
-- order by currency desc, calendar_date desc