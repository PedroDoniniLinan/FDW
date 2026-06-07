{{ config(schema='silver', materialized='view') }}

select *
from {{ref("int_fiat_transactions")}}
where amount != 0
union all
select
    null as transaction_id,
    calendar_date,
    original_currency||'/'||currency as tag,
    original_currency,
    currency,
    'Income' as transaction_type,
    original_currency as label,
    account,
    dod_capital_gain as original_amount,
    1 as price,
    dod_capital_gain as amount
from {{ref('int_gains_daily')}}
where dod_capital_gain != 0
union all
select
    null as transaction_id,
    calendar_date,
    original_currency||'/exchange' as tag,
    original_currency,
    currency,
    'Income' as transaction_type,
    original_currency as label,
    account,
    exchange_capital_gains as original_amount,
    1 as price,
    exchange_capital_gains as amount
from {{ref('int_gains_daily')}}
where exchange_capital_gains != 0