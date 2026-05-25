{{ config(schema='silver', materialized='table') }}

select
    t.transaction_id,
    t.calendar_date,
    t.tag,
    t.original_currency,
    t.currency,
    t.transaction_type,
    t.label,
    tc.budget_level,
    tc.level_1,
    tc.level_2,
    tc.level_3,
    tc.source,
    t.account,
    ac.account_country,
    ac.budget_level as account_budget_level,
    t.original_amount,
    t.price,
    {# round(t.amount::numeric, 7) as amount #}
    t.amount
from {{ref("int_transactions_and_gains")}} t
    left join {{ref("stg_dim_transactions")}} tc on (t.label = tc.label and t.transaction_type = tc.transaction_type)
    left join {{ref("dim_account")}} ac on (t.account = ac.account)