{{ config(schema='silver', materialized='table') }}


select *
from {{ref("int_balances_daily_ext")}}
where calendar_date = (select max(calendar_date) from {{ref("int_balances_daily_ext")}})