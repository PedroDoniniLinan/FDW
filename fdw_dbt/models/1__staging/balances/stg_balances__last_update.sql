{%- set src = source('bronze', 'balances') -%}

select max(calendar_date) as last_update
from {{ src }}
