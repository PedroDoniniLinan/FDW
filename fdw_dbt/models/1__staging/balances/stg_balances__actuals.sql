{%- set src = source('bronze', 'balances') -%}

select 
    balance_id,
    account,
    currency,
    calendar_date,
    balance
from (
    select 
        id as balance_id,
        account,
        currency,
        calendar_date,
        amount as balance,
        {# {{round_amount('amount', 'currency')}} as balance, #}
        row_number() over (partition by account, currency, calendar_date order by id desc) as rn
    from {{ src }}
) ranked
where rn = 1
