{%- set src = source('bronze', 'balances') -%}

select distinct
    md5(currency) as currency_id,
    currency
from {{ src }}
