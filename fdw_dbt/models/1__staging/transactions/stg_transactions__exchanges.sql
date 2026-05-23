{%- set src = source('bronze', 'exchanges') -%}

select
    md5(id::text||'_ext')::uuid as transaction_id,
    'Exchange' as transaction_type,
    case when exchange_type = 'Purchase' then ticker||'<-'||currency
        else currency||'<-'||ticker
    end as transaction_description,
    case when exchange_type = 'Purchase' then units
        else -units
    end as units,
    account,
    calendar_date,
    exchange_type as category,
    ticker as asset,
    true as count_to_balance,
    currency as exchange_asset,
    price as exchange_rate,
    tax_currency as tax_asset,
    tax as tax_units
from {{ src }}
union all
select
    md5(id::text||'_exc')::uuid as transaction_id,
    'Exchange' as transaction_type,
    case when exchange_type = 'Purchase' then ticker||'<-'||currency
        else currency||'<-'||ticker
    end as transaction_description,
    case when exchange_type = 'Purchase' then -price*units
        else price*units
    end as units,
    account,
    calendar_date,
    case when exchange_type = 'Purchase' then 'Sale' 
        else 'Purchase'
    end as category,
    currency as asset,
    true as count_to_balance,
    ticker as exchange_asset,
    1/nullif(price, 0) as exchange_rate,
    tax_currency as tax_asset,
    tax as tax_units        
from {{ src }}