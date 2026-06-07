{{ config(schema='silver', materialized='table') }}

select
    ad.account,
    ac.account_country,
    ac.budget_level as account_budget_level,
    ad.currency,
    ad.original_currency,
    tc.level_1,
    tc.level_2,
    tc.level_3,
    tc.source,
    ad.calendar_date,
    ad.is_end_of_period,
    ad.original_balance,
    ad.price,
    ad.balance
from {{ref("int_fiat_balances_daily")}} ad
    left join {{ref("stg_dim_transactions")}} tc on (ad.original_currency = tc.label and tc.transaction_type = 'Income')
    left join {{ref("account_categories")}} ac on (ad.account = ac.account)
{# where ad.balance > 0 #}