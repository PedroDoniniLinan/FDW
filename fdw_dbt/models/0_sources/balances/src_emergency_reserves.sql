{{ config(schema='silver', materialized='view') }}

{# {% set accounts_d = [''] %} #}

{# select
    level_3,
    sum(target_balance) as emergency_reserves
from {{ref("target_cash_reserves")}}
where level_3 is not null
group by level_3 #}

with 

    targets as (
        select
            level_3,
            sum(target_balance) as emergency_reserves
        from {{ref("target_cash_reserves")}}
        where level_3 is not null
        group by level_3
    ),

    excluded_balance as (
        select
            original_currency as level_3,
            sum(balance) as emergency_reserves
        from {{ ref("int_fiat_balances_daily") }}
        where currency = 'EUR'
            and account in ('Nubank D', 'Wise D', 'Payoneer')
            and calendar_date = (select max(calendar_date) from {{ ref("int_fiat_balances_daily") }})
        group by level_3
    )


select
    level_3,
    sum(emergency_reserves) as emergency_reserves
from (
    select * from excluded_balance
    union all
    select * from targets
) t
group by level_3