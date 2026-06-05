{{ config(schema='gold', materialized='table') }}

with

    cash_balances as (      
        select
            account,
            source,
            case when account = 'Wise D' and level_3 in ('EUR') then 'USD' else level_3 end as level_3,
            sum(balance) as balance
        from {{ref("balances_mart")}}
        where calendar_date = (select max(calendar_date) from {{ref("balances_mart")}} where balance > 0 and currency != 'Original')
            and currency != 'Original'
            and currency = 'EUR'
            and (source = 'Cash' or level_3 = 'Nubank')
        group by 
            account,
            source,
            case when account = 'Wise D' and level_3 in ('EUR') then 'USD' else level_3 end
    ),

    targets as (
        select 
            c.*,
            t.emergency_tier,
            t.target_balance,
            (balance - coalesce(target_balance, 0)) as free_cash
        from cash_balances c
            left join {{ref("target_cash_reserves")}} t on (c.account = t.account and c.level_3 = t.level_3)
    )

{# select * from targets #}

select
    sum(case when emergency_tier = 1 then target_balance end) as tier_1_emergency_reserves,
    sum(case when emergency_tier is not null then target_balance end) as emergency_reserves,
    sum(balance) as actual_reserve,
    sum(free_cash) as free_cash
from targets