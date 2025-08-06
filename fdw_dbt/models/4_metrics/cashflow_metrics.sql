{{ config(schema='gold', materialized='table') }}

select
    calendar_date,
    currency,
    transaction_type,
    budget_level,
    level_1,
    level_2,
    level_3,
    source,
    account,
    account_country,
    sum(amount) as amount,
    {# sum(round(amount::numeric, 7)) as amount, #}
    case when transaction_type = 'Expenses' then -sum(amount) else sum(amount) end as absolute_amount
    {# case when transaction_type = 'Expenses' then -sum(round(amount::numeric, 7)) else sum(round(amount::numeric, 7)) end as absolute_amount #}
from {{ref("transactions_mart")}}
where transaction_type in ('Income', 'Expenses')
group by
    calendar_date,
    currency,
    transaction_type,
    budget_level,
    level_1,
    level_2,
    level_3,
    source,
    account,
    account_country