select
    t.transaction_id,
    t.calendar_date,
    t.transaction_description,
    t.asset,
    t.currency,
    t.transaction_type,
    t.category,
    tc.financial_level_1,
    tc.financial_level_2,
    tc.budget_level_1,
    tc.budget_level_2,
    tc.budget_level_3,
    tc.source,
    t.account,
    ac.account_country,
    ac.budget_level as account_budget_level,
    t.units,
    t.exchange_rate,
    t.amount
from {{ref("int_transactions__all_with_gains")}} t
    left join {{ref("int_transaction_categories__united")}} tc on (t.category = tc.category and t.transaction_type = tc.transaction_type)
    left join {{ref("dim_account")}} ac on (t.account = ac.account)