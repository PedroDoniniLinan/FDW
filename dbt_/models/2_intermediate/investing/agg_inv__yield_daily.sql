{{
    config(
        tags=['refactored', 'main', 'rated'],
        materialized='incremental',
        incremental_strategy='microbatch',
        unique_key=['calendar_date', 'currency', 'budget_level_1', 'budget_level_2', 'budget_level_3'],
        event_time='calendar_date',
        begin='2019-01-01',
        batch_size='year',
        lookback=1
    )
}}

{#
    Microbatch by calendar year. Each batch covers every key (int_inv__yield_keys, full history) on every day of
    its year. prev_balance on the first day of a batch comes from the last day of the previous year, read from
    the existing table (the carry-over seed). The seed day is not written.
#}

with

daily_aggregates as (
    select * from {{ ref('int_inv__yield_daily_aggregates') }}
),

keys as (
    select
        currency,
        budget_level_1,
        budget_level_2,
        budget_level_3
    from {{ ref('int_inv__yield_keys') }}
),

first_day as (
    select min(calendar_date) as first_day
    from daily_aggregates
),

{% if is_incremental() %}
-- last day of the previous batch, from the existing table (not written to the output)
seed_balances as (
    select
        t.calendar_date,
        t.currency,
        t.budget_level_1,
        t.budget_level_2,
        t.budget_level_3,
        t.balance,
        0::numeric as interest
    from {{ this }} as t
    cross join first_day as f
    where t.calendar_date = f.first_day - 1
),

aggregates_with_seed as (
    select * from daily_aggregates
    union all
    select * from seed_balances
),
{% else %}
aggregates_with_seed as (
    select * from daily_aggregates
),
{% endif %}

calendar as (
    select generate_series(min(calendar_date), max(calendar_date), interval '1 day')::date as calendar_date
    from aggregates_with_seed
),

daily_spine as (
    select
        c.calendar_date,
        k.currency,
        k.budget_level_1,
        k.budget_level_2,
        k.budget_level_3,
        coalesce(a.balance, 0) as balance,
        coalesce(a.interest, 0) as interest
    from keys as k
    cross join calendar as c
    left join aggregates_with_seed as a
        on c.calendar_date = a.calendar_date
        and k.currency = a.currency
        and k.budget_level_1 = a.budget_level_1
        and k.budget_level_2 = a.budget_level_2
        and k.budget_level_3 = a.budget_level_3
),

daily_with_previous as (
    select
        calendar_date,
        currency,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        balance,
        interest,
        coalesce(lag(balance) over (
            partition by currency, budget_level_1, budget_level_2, budget_level_3
            order by calendar_date
        ), 0) as prev_balance
    from daily_spine
),

final as (
    select
        calendar_date,
        currency,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        balance,
        interest,
        prev_balance,
        balance - prev_balance - interest as flow
    from daily_with_previous
    where calendar_date >= (select f.first_day from first_day as f)
)

select * from final
