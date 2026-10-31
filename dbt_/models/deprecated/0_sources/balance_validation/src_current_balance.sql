{{ config(schema='bronze', materialized='view') }}

select 
    account,
    currency,
    calendar_date,
    balance
from (
    select 
        account,
        currency,
        calendar_date,
        {{round_amount('amount', 'currency')}} as balance,
        row_number() over (partition by account, currency order by calendar_date desc) as rn
    from {{ source('bronze', 'balances') }}
    where calendar_date = (select max(calendar_date) as max_date from {{ source('bronze', 'balances') }})
) ranked
where rn = 1