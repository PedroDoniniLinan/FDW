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
        from {{ref("int_prices__united")}}
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
            left join {{ref("int_shared__daily_grid")}} g on (
                g.calendar_date between l.calendar_date and coalesce(l.next_calendar_date, l.calendar_date)
            )
    )

select *
from daily_prices