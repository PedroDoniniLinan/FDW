{{ config(schema='silver', materialized='table') }}

with

    monthly_performance as (
        select
            currency,
            i.level_3,
            ticker,
            calendar_date,
            price,
            lag(price) over (partition by currency, ticker order by calendar_date) as prev_price,
            (price - lag(price) over (partition by currency, ticker order by calendar_date))
                /nullif(lag(price) over (partition by currency, ticker order by calendar_date), 0) as performance
        from {{ref("int_prices_daily")}} p
            inner join (
                select distinct label, level_3, transaction_type
                from {{ref("stg_dim_transactions")}}
            ) i on (p.ticker = i.label and i.transaction_type = 'Income')
            inner join (
                select distinct level_3
                from {{ref("target_allocation")}}
            ) t on (i.level_3 = t.level_3)
        where is_end_of_period ~* 'month'
            -- and currency = 'BRL'
            and currency = 'EUR'
    ),

    dividends as (
        select
            u.currency,
            u.level_3,
            u.ticker,
            u.calendar_date,
            {# (u.performance) as performance #}
            (u.performance + coalesce(d.performance, 0)) as performance
        from monthly_performance u
            left join {{ref("int_dividend_yields_monthly")}} d on (
                u.currency = d.currency 
                and u.ticker = d.ticker
                and date_trunc('month', u.calendar_date) = d.calendar_date
            )
        where not(
            u.ticker != u.currency
            and (u.performance + coalesce(d.performance, 0)) = 0
        )
    ),

    level_3_avg as (
        select
            currency,
            calendar_date,
            level_3,
            sum(coalesce(performance, 0))/nullif(count(case when performance is not null then 1 end), 0) as performance
        from dividends
        group by
            currency,
            calendar_date,
            level_3
    ),

    ticker_features as (
        select
            currency,
            level_3,
            min(calendar_date) as min_date,
            max(calendar_date) as max_date,
            avg(performance) as performance
        from level_3_avg
        group by currency, level_3
    ),

    daily_filler as (
        select
            tf.currency,
            tf.level_3,
            g.calendar_date,
            (1 + performance) as performance
            {# round((1 + performance)::numeric, 5) as performance #}
        from ticker_features tf
            left join {{ref('src_daily_grid')}} g on (g.calendar_date between '2022-01-31'::date and tf.min_date)
        where g.is_end_of_period ~* 'month'
    ),

    unite_filler as (
        select * from daily_filler
        union all
        select 
            currency,
            level_3,
            calendar_date,
            (1 + performance) as performance
        from level_3_avg
        {# where calendar_date >= '2022-01-01' #}
        where performance is not null
    )

select
    currency,
    level_3,
    date_trunc('month', calendar_date)::date as calendar_date,
    performance
from unite_filler

-- select *
-- from unite_filler
-- where level_3 = 'EUR212'


