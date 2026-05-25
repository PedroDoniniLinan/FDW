{{ config(schema='silver', materialized='view') }}

select
    coalesce(cb.account, ab.account) as account,
    coalesce(cb.currency, ab.currency) as currency,
    coalesce(cb.calendar_date, ab.calendar_date) as calendar_date,
    cb.balance as balance_actual,
    coalesce(ab.balance, 0) as balance_calculated,
    (coalesce(ab.balance, 0) - cb.balance) as delta
from {{ref("int_balances_daily_ext")}} ab
    full outer join {{ref("src_balance_checks")}} cb on (
        cb.account = ab.account
        and cb.currency = ab.currency
        and cb.calendar_date = ab.calendar_date
    )
where (coalesce(ab.balance, 0) - cb.balance) is not null