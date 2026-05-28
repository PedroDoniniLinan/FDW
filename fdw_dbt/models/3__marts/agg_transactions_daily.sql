select
    md5(calendar_date::text || currency || transaction_type || financial_level_1 || financial_level_2 || budget_level_1 
        || budget_level_2 || budget_level_3 || account || account_country) as unique_id,
    calendar_date,
    currency,
    transaction_type,
    financial_level_1,
    financial_level_2,
    budget_level_1,
    budget_level_2,
    budget_level_3,
    account,
    account_country,
    sum(amount) as amount,
    case when transaction_type = 'Expenses' then -sum(amount) else sum(amount) end as absolute_amount
from {{ref('fct_transactions_enriched')}}
where transaction_type in ('Income', 'Expenses')
group by
    generic_id,
    calendar_date,
    currency,
    transaction_type,
    financial_level_1,
    financial_level_2,
    budget_level_1,
    budget_level_2,
    budget_level_3,
    account,
    account_country