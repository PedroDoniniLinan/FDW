{{ config(schema='gold', materialized='view') }}

select
    coalesce(cb.account, ab.account) as account,
    coalesce(cb.currency, ab.currency) as currency,
    coalesce(cb.calendar_date, ab.calendar_date) as calendar_date,
    coalesce(cb.balance, 0) as balance_actual,
    coalesce(ab.balance, 0) as balance_calculated,
    (coalesce(ab.balance, 0) - coalesce(cb.balance, 0)) as delta
from {{ref("src_current_balance")}} cb
    left join {{ ref("int_current_balance_ext") }} ab on (
        cb.account = ab.account
        and cb.currency = ab.currency
    )
where (coalesce(ab.balance, 0) - coalesce(cb.balance, 0)) != 0