{{ config(materialized='view', tags=['refactored', 'projections']) }}

with recursive

apports as (
    select
        calendar_date,
        simulation_set,
        apport
    from {{ ref('fct_prj__apports_monthly') }}
),

starting_balances as (
    select
        '2023-12-01'::date as calendar_date,
        sum(balance) as balance
    from {{ ref('fct_blc__balances_daily') }}
    where calendar_date = '2023-12-31'::date
        and currency = 'EUR'
        and account <> 'Nubank C'
    group by calendar_date
),

simulation_set_rates as (
    select
        simulation_set,
        power(1 + fixed_rate, 1.0 / 12) - 1 as monthly_rate
    from {{ ref('simulation_set_rates') }}
),

simulation_months as (
    select
        calendar_date,
        simulation_set
    from apports
    group by calendar_date, simulation_set
),

monthly_balance (
    calendar_date,
    simulation_set,
    monthly_rate,
    apport,
    prev_balance,
    interest,
    balance
) as (
    select
        m.calendar_date,
        m.simulation_set,
        r.monthly_rate,
        a.apport,
        s.balance::double precision as prev_balance,
        0::double precision as interest,
        (s.balance::double precision + a.apport) as balance
    from simulation_months as m
    inner join starting_balances as s
        on m.calendar_date = s.calendar_date
    inner join simulation_set_rates as r
        on m.simulation_set = r.simulation_set
    inner join apports as a
        on m.calendar_date = a.calendar_date
        and m.simulation_set = a.simulation_set

    union all

    select
        m.calendar_date,
        m.simulation_set,
        previous.monthly_rate,
        a.apport,
        previous.balance as prev_balance,
        previous.balance * previous.monthly_rate as interest,
        previous.balance * (1 + previous.monthly_rate) + a.apport as balance
    from monthly_balance as previous
    inner join simulation_months as m
        on m.simulation_set = previous.simulation_set
        and m.calendar_date = (date_trunc('month', previous.calendar_date) + interval '1 month')::date
    inner join apports as a
        on m.calendar_date = a.calendar_date
        and m.simulation_set = a.simulation_set
),

final as (
    select
        calendar_date,
        simulation_set,
        monthly_rate,
        apport,
        prev_balance,
        interest,
        balance
    from monthly_balance
)

select * from final
