{{ config(schema='silver', materialized='view') }}

with

    fiat_conversion as (
        select
            e.calendar_date,
            e.exchange_type,
            e.exchange_direction,
            e.ticker,
            dp.currency as currency,
            case 
                when ic.irs_category is not null then ic.irs_category 
                when e.ticker ~* '^(td|cdb|lci|lca|cri|cra|deb)' then 'Foreign bonds'
                else 'Other' 
            end as irs_category,
            e.price * dp.price as price,
            abs(e.amount) as abs_amount,
            amount as net_amount,
            case 
                when tax_currency = dp.currency then e.price * dp.price * e.amount + e.tax_amount * dpt.price
                else e.price * dp.price * e.amount
            end as exchange_value,
            case 
                when e.ticker = tax_currency then e.tax_amount
                else e.tax_amount * dpt.price 
            end as tax,
            --
            e.amount as original_amount,
            e.exchange_currency as original_currency,
            e.price as original_price,
            dp.price as fiat_price,
            e.tax_currency,
            e.tax_amount,
            dpt.price as tax_fiat_price,
            dpt.currency as tax_fiat_currency,
            (CURRENT_DATE - e.calendar_date) as purchase_age
        from {{ref("stg_exchange_classifications")}} e
            left join {{ref("int_prices_daily")}} dp on (
                e.exchange_currency = dp.ticker
                and e.calendar_date = dp.calendar_date
                and dp.currency in ('BRL', 'EUR')
                -- and e.exchange_type = 'Taxable exchange'
            )
            left join {{ref("int_prices_daily")}} dpt on (
                e.tax_currency = dpt.ticker
                and e.calendar_date = dpt.calendar_date
                and dpt.currency = dp.currency
                and e.exchange_type = 'Taxable exchange'
            )
            left join {{ref("irs_category")}} ic on (
                e.ticker = ic.ticker
            )
    ),

    total_amounts as (
        select
            calendar_date,
            exchange_type,
            exchange_direction,
            ticker,
            currency,
            irs_category,
            price,
            abs_amount,
            net_amount,
            exchange_value,
            coalesce(tax, 0) as tax,
            sum(net_amount) over (partition by ticker, currency order by calendar_date, abs_amount) as total_amount,
            purchase_age,
            sum(abs_amount) over (partition by ticker, currency, exchange_direction order by calendar_date, abs_amount) as cumulative_amount
        from fiat_conversion
    )

select *,
    coalesce(lag(cumulative_amount) over (partition by ticker, currency, exchange_direction order by calendar_date, abs_amount), 0) as previous_cumulative_amount
from total_amounts
where ticker not in (
    'AXS', 'SLP', 'ATLAS', 'BUSD', 'THC', 'THG', 'SAND', 'LTC', 'FINA', 
    'BCOIN', 'RON', 'POLIS', 'LUNA', 'LUNA2', 'SHIB', 'ADA')
order by calendar_date, ticker, abs_amount