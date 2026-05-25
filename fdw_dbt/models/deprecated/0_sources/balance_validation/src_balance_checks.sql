{{ config(schema='bronze', materialized='view') }}

select 
    account,
    currency,
    calendar_date,
    balance
from (
    select 
        id,
        account,
        currency,
        calendar_date,
        {{round_amount('amount', 'currency')}} as balance,
        row_number() over (partition by account, currency, calendar_date order by id desc) as rn
    from {{ source('bronze', 'balances') }}
) ranked
where rn = 1
