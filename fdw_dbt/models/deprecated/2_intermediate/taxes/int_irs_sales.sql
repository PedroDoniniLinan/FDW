{{ config(schema='silver', materialized='view') }}

{%- set irs_start_date = '2025-01-01' -%}
{%- set min_sale_value = 100 -%}

with

    tax_due as (
        select
            ie.purchase_date,
            ie.sale_date,
            ie.ticker,
            ie.currency,
            ie.irs_category,
            ie.purchase_price,
            ie.sale_price,
            ie.purchase_amount,
            ie.sale_amount,
            ie.tax,
            ie.holding_period,
            (ie.sale_price - ie.purchase_price) * abs(ie.matched_amount) as gain_loss,
            ir.rate as irs_rate,
            ((ie.sale_price - ie.purchase_price) * abs(ie.matched_amount)) * ir.rate as tax_due,
            ie.matched_amount
        from {{ref("int_irs_fifo_exchanges")}} ie
            left join {{ ref("irs_rates") }} ir on (
                ie.irs_category = ir.irs_category
                and ie.holding_period >= ir.holding_period_lower
                and (ie.holding_period <= ir.holding_period_upper or ir.holding_period_upper is null)
            )
        where sale_date is not null
            and sale_date >= '{{ irs_start_date }}'
            and abs(sale_exchange_value) > abs({{ min_sale_value }})
            and ie.irs_category not in ('Other', 'Foreign bonds', 'Cash')
    )

select
    purchase_date,
    sale_date,
    ticker,
    currency,
    irs_category,
    matched_amount,
    round((purchase_price*matched_amount)::numeric, 2) as purchase_value,
    purchase_price,
    purchase_amount,
    round((sale_price*matched_amount)::numeric, 2) as sale_value,
    sale_price,
    sale_amount,
    holding_period,
    gain_loss,
    irs_rate,
    tax_due
from tax_due
where tax_due > 10 or tax_due <= 0
order by sale_date, purchase_date