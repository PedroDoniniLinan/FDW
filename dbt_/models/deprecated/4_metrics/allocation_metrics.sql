{{ config(schema='gold', materialized='table') }}
{% set levels = ['1', '2', '3'] %}

with

    agg_balance as (
        select
            currency,
            calendar_date,
            level_1,
            level_2,
            level_3,
            source,
            sum(balance) as balance
        from {{ref("balances_mart")}}
        where calendar_date = (select max(calendar_date) from {{ref("balances_mart")}} where balance > 0 and currency != 'Original')
            and currency != 'Original'
            and currency = 'EUR'
            and balance > 0
        group by 
            currency,
            calendar_date,
            level_1,
            level_2,
            level_3,
            source
    ),

    available_balance as (
        select
            a.currency,
            a.calendar_date,
            a.level_1,
            a.level_2,
            a.level_3,
            a.source,
            coalesce(a.balance, 0) as balance,
            (coalesce(a.balance, 0) - coalesce(e.emergency_reserves, 0)) as available_balance,
            round(((coalesce(a.balance, 0) - coalesce(e.emergency_reserves, 0))
                /sum((coalesce(a.balance, 0) - coalesce(e.emergency_reserves, 0))) over ())::numeric, 7) as allocation,
            t.target_allocation,
            (t.target_allocation 
                - round(((coalesce(a.balance, 0) - coalesce(e.emergency_reserves, 0))
                    /sum((a.balance - coalesce(e.emergency_reserves, 0))) over ())::numeric, 7)) as allocation_delta,
            sum((coalesce(a.balance, 0) - coalesce(e.emergency_reserves, 0))) over ()
                *(t.target_allocation 
                    - round(((coalesce(a.balance, 0) - coalesce(e.emergency_reserves, 0))
                        /sum((coalesce(a.balance, 0) - coalesce(e.emergency_reserves, 0))) over ())::numeric, 7)) as balance_delta
        from agg_balance a
            left join {{ref("src_emergency_reserves")}} e on (a.level_3 = e.level_3)
            full outer join {{ref("int_allocation_targets")}} t on (a.level_3 = t.level_3)
    ),

    convert_currencies as (
        select
            -- a.currency,
            p.currency,
            p.calendar_date,
            level_1,
            level_2,
            level_3,
            source,
            round((p.price*balance)::numeric, 4) as balance,
            round((p.price*available_balance)::numeric, 4) as available_balance,
            allocation,
            target_allocation,
            allocation_delta,
            round((p.price*balance_delta)::numeric, 4) as balance_delta
        from available_balance a
            left join {{ref("int_prices_daily")}} p on (a.currency = p.ticker and p.calendar_date = a.calendar_date)
    )

{% for l in levels %}
select
    currency,
    '{{l}}' as asset_level,
    level_1,
    case when '{{l}}' = 1 then level_1 else level_2 end as level_2,
    level_{{l}} as asset,
    round(sum(available_balance)::numeric, 5) as available_balance,
    round(sum(allocation)::numeric, 5) as allocation,
    round(sum(target_allocation)::numeric, 5) as target_allocation,
    round(sum(allocation_delta)::numeric, 5) as allocation_delta,
    round(sum(balance_delta)::numeric, 5) as balance_delta,
    case when currency in ('EUR', 'USD') then abs(round(sum(balance_delta)::numeric, 5)) > 200
        else abs(round(sum(balance_delta)::numeric, 5)) > 1300
    end as is_actionable
from convert_currencies
group by currency, asset_level, level_1, case when '{{l}}' = 1 then level_1 else level_2 end, asset
{% if not loop.last %}union all{% endif %}{% endfor %}
order by asset_level, target_allocation desc
