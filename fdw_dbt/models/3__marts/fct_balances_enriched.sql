select
    ad.balance_id,
    ad.calendar_date,
    ad.is_end_of_period,
    ad.asset,
    ad.currency,
    ad.account,
    ac.account_country,
    ac.budget_level as account_budget_level,
    tc.level_1,
    tc.level_2,
    tc.level_3,
    tc.source,
    ad.balance
from {{ref("int_balances__fiat_converted_daily")}} ad
    left join {{ref("int_transaction_categories__united")}} tc on (ad.asset = tc.category and tc.transaction_type = 'Income')
    left join {{ref("dim_account")}} ac on (ad.account = ac.account)