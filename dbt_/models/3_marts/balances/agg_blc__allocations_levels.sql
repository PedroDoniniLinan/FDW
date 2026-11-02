{{ config(
    materialized='table',
    tags=['refactored', 'main', 'mart', 'rated']
) }}

{% set levels = ['1', '2', '3'] %}

with

raw_allocation_positions as (
    select
        currency,
        calendar_date,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        source,
        balance,
        available_balance,
        allocation,
        target_allocation,
        allocation_delta,
        balance_delta
    from {{ ref("fct_blc__allocations_daily") }}
),

raw_prices as (
    select asset, currency, calendar_date, exchange_rate
    from {{ ref("fct_inv__rates_fiat_daily") }}
),

converted_currencies as (
    select
        p.currency,
        p.calendar_date,
        a.budget_level_1,
        a.budget_level_2,
        a.budget_level_3,
        a.source,
        round((p.exchange_rate * a.balance)::numeric, 4) as balance,
        round((p.exchange_rate * a.available_balance)::numeric, 4) as available_balance,
        a.allocation,
        a.target_allocation,
        a.allocation_delta,
        round((p.exchange_rate * a.balance_delta)::numeric, 4) as balance_delta
    from raw_allocation_positions as a
    left join raw_prices as p
        on a.currency = p.asset
        and p.calendar_date = a.calendar_date
),

allocation_levels as (
    {% for l in levels %}
    select
        currency,
        '{{ l }}' as asset_level,
        budget_level_1,
        case when '{{ l }}' = '1' then budget_level_1 else budget_level_2 end as budget_level_2,
        budget_level_{{ l }} as asset,
        round(sum(available_balance)::numeric, 5) as available_balance,
        round(sum(allocation)::numeric, 5) as allocation,
        round(sum(target_allocation)::numeric, 5) as target_allocation,
        round(sum(allocation_delta)::numeric, 5) as allocation_delta,
        round(sum(balance_delta)::numeric, 5) as balance_delta,
        case
            when currency in ('EUR', 'USD') then abs(round(sum(balance_delta)::numeric, 5)) > 200
            else abs(round(sum(balance_delta)::numeric, 5)) > 1300
        end as is_actionable
    from converted_currencies
    group by 1, 2, 3, 4, 5
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
)

select
    currency,
    asset_level,
    budget_level_1,
    budget_level_2,
    asset,
    available_balance,
    allocation,
    target_allocation,
    allocation_delta,
    balance_delta,
    is_actionable
from allocation_levels
