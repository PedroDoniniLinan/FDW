{{ config(schema='gold', materialized='view') }}

select *
from (
    select
        t.ticker,
        currency,
        calendar_date as last_purchase_date,
        avg_price,
        units,
        position,
        tc.taxable_currency,
        row_number() over (partition by t.ticker, currency order by calendar_date desc) as rn
    from {{source('silver', 'taxes_avg_price_raw')}} t
        inner join {{ref("taxes_categories")}} tc on (t.ticker = tc.ticker)
    where calendar_date < '2025-01-01' 
) t
where 1=1
    and rn = 1
    -- and ticker = 'GOGL34'
    and units > 0