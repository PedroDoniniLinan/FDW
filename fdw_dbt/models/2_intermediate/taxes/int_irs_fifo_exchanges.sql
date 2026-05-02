{{ config(schema='silver', materialized='view') }}

with

    purchases as (
        select *
        from {{ref("int_fiat_exchanges")}}
        where 1=1
        {# and ticker = 'BTC' #}
        and currency = 'EUR'
        and exchange_direction = 'Purchase'
    ),

    sales as (
        select *
        from {{ref("int_fiat_exchanges")}}
        where 1=1
        {# andticker = 'BTC' #}
        and currency = 'EUR'
        and exchange_direction = 'Sale'
    ),

    joined_operations as (
        select
            p.calendar_date as purchase_date,
            s.calendar_date as sale_date,
            p.ticker,
            p.currency,
            p.irs_category,
            p.price as purchase_price,
            s.price as sale_price,
            p.net_amount as purchase_amount,
            s.net_amount as sale_amount,
            p.tax,
            s.exchange_value as sale_exchange_value,
            p.purchase_age,
            (s.calendar_date::date - p.calendar_date::date) as holding_period,
            p.cumulative_amount as purchase_cumulative_amount,
            s.cumulative_amount as sale_cumulative_amount,
            p.previous_cumulative_amount as purchase_previous_cumulative_amount,
            s.previous_cumulative_amount as sale_previous_cumulative_amount,
            case 
                when s.cumulative_amount >= p.cumulative_amount and s.previous_cumulative_amount <= p.previous_cumulative_amount then p.abs_amount
                when p.cumulative_amount >= s.cumulative_amount and p.previous_cumulative_amount <= s.previous_cumulative_amount then s.abs_amount
                when s.cumulative_amount between p.previous_cumulative_amount and p.cumulative_amount then s.cumulative_amount - p.previous_cumulative_amount
                when s.previous_cumulative_amount between p.previous_cumulative_amount and p.cumulative_amount then p.cumulative_amount - s.previous_cumulative_amount
            end as matched_amount
        from purchases p
        left join sales s on (
            p.ticker = s.ticker
            and p.currency = s.currency
            and (s.cumulative_amount between p.previous_cumulative_amount and p.cumulative_amount
                or s.previous_cumulative_amount between p.previous_cumulative_amount and p.cumulative_amount
                or s.cumulative_amount > p.cumulative_amount and s.previous_cumulative_amount < p.previous_cumulative_amount)
        )
    )

select *
from joined_operations
order by purchase_date, purchase_cumulative_amount, sale_cumulative_amount