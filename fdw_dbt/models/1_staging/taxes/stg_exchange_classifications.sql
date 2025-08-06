{{ config(schema='silver', materialized='view') }}

with

    exchange_types as (
        select
            case
                when currency in {{fiat_currencies_ext()}} then 'Fiat exchange'
                when exchange_currency not in {{fiat_currencies_ext()}} then 'Not fiat exchange'
                else 'Taxable exchange'
            end as exchange_type,
            calendar_date,
            subcategory as exchange_direction,
            currency as ticker,
            exchange_currency,
            price,
            amount,
            tax_currency,
            tax_amount
        from {{ref("src_exchange_transactions")}}
        union all
        select
            'Transaction' as exchange_type,
            calendar_date,
            case when amount > 0 then 'Purchase' else 'Sale' end as exchange_direction,
            currency as ticker,
            currency as exchange_currency,
            1 as price,
            amount,
            currency as tax_currency,
            0 as tax_amount
        from {{ref("src_external_transactions")}}
        where currency not in {{fiat_currencies_ext()}}
    )

select *
from exchange_types
where exchange_type != 'Fiat exchange'
