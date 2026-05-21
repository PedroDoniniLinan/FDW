{%- set src = source('bronze', 'balances') -%}

select 
    extract_id,
    account,
    asset,
    calendar_date,
    units
from (
    select 
        id as extract_id,
        account,
        currency as asset,
        calendar_date,
        amount as units,
        row_number() over (partition by account, currency, calendar_date order by id desc) as rn
    from {{ src }}
) ranked
where rn = 1
