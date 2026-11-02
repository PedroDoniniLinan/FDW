select distinct
    transaction_type,
    financial_level_1,
    financial_level_2,
    budget_level_1,
    budget_level_2,
    budget_level_3
from {{ ref("fct_trx__transactions_enriched_daily") }}
{# where transaction_type in ('Expenses') #}
where transaction_type in ('Income')
order by 1, 2, 4