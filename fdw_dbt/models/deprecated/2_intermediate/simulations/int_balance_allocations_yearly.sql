{{ config(schema='silver', materialized='table') }}

with

    yearly_balance as (
        select
            (calendar_date + interval '1 day')::date as calendar_date,
            currency,
            sum(balance) as balance
        from {{ref("int_fiat_balances_daily_star")}}
        where is_end_of_period ~* 'year'
            and calendar_date < date_trunc('year', current_date)
            and currency = 'EUR'
        group by 1, 2
    ),

    asset_allocation as (
        select distinct a.*, t.level_2
        from {{ref("asset_simulated_allocations")}} a
            left join {{ref("stg_dim_transactions")}} t on (a.currency = t.level_3)
    ),

    allocations as (
        select y.*, sa.*, aa.currency as asset, aa.allocation as asset_allocation, y.balance*sa.allocation*aa.allocation as allocated_balance
        from yearly_balance y
            cross join {{ref("simulated_allocations")}} sa
            left join asset_allocation aa on (sa.level_2 = aa.level_2 and sa.asset_set = aa.set)
    )

select *
from allocations
order by calendar_date, currency, level_2, allocated_balance desc
