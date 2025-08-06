{{ config(schema='bronze', materialized='view') }}

select
    id::text||'_ext' as transaction_id,
    'Exchange' as transaction_type,
    case when exchange_type = 'Purchase' then ticker||'<-'||currency
        else currency||'<-'||ticker
    end as tag,
    {# case when exchange_type = 'Purchase' then {{round_amount('units', 'ticker')}}
        else -{{round_amount('units', 'ticker')}}
    end as amount, #}
    case when exchange_type = 'Purchase' then units
        else -units
    end as amount,
    account,
    calendar_date,
    exchange_type as subcategory,
    ticker as currency,
    true as count_to_balance,
    currency as exchange_currency,
    price,
    tax as tax_amount,
    {# {{round_amount('price', 'currency')}} as price,
    {{round_amount('tax', 'tax_currency')}} as tax_amount, #}
    tax_currency
from {{ source('bronze', 'exchanges') }}
union all
select
    id::text||'_exc' as transaction_id,
    'Exchange' as transaction_type,
    case when exchange_type = 'Purchase' then ticker||'<-'||currency
        else currency||'<-'||ticker
    end as tag,
    {# case when exchange_type = 'Purchase' then -{{round_amount('(price*units)', 'currency')}}
        else {{round_amount('(price*units)', 'currency')}}
    end as amount, #}
    case when exchange_type = 'Purchase' then -price*units
        else price*units
    end as amount,
    account,
    calendar_date,
    case when exchange_type = 'Purchase' then 'Sale' 
        else 'Purchase'
    end as subcategory,
    currency,
    true as count_to_balance,
    ticker as exchange_currency,
    1/nullif(price, 0) as price,
    tax as tax_amount,        
    {# {{round_amount('1/nullif(price, 0)', 'currency')}} as price,
    {{round_amount('tax', 'tax_currency')}} as tax_amount, #}
    tax_currency
from {{ source('bronze', 'exchanges') }}