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
        simulation_set,
        case
            when extract(year from calendar_date) between 2030 and 2077
                then 1 - 0.77 * (extract(year from calendar_date) - 2030) / 47.0
            else 1
        end::double precision as interest_factor,
        case
            when extract(year from calendar_date) between 2045 and 2077
                then 1 - 0.63 * (extract(year from calendar_date) - 2045) / 32.0
            else 1
        end::double precision as interest_factor_2,
        case
            when extract(year from calendar_date) between 2055 and 2077
                then 1 - 0.42 * (extract(year from calendar_date) - 2055) / 22.0
            else 1
        end::double precision as interest_factor_3
    from apports
    group by calendar_date, simulation_set
),

monthly_balance (
    calendar_date,
    simulation_set,
    monthly_rate,
    adjusted_rate,
    apport,
    prev_balance,
    interest,
    balance
) as (
    select
        m.calendar_date,
        m.simulation_set,
        r.monthly_rate,
        r.monthly_rate as adjusted_rate,
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
        case
            when previous.monthly_rate > 0.011
                then previous.monthly_rate * m.interest_factor
            when previous.monthly_rate > 0.007
                then previous.monthly_rate * m.interest_factor_2
            else previous.monthly_rate * m.interest_factor_3
        end as adjusted_rate,
        a.apport,
        previous.balance as prev_balance,
        case
            when previous.monthly_rate > 0.011
                then previous.balance * previous.monthly_rate * m.interest_factor
            when previous.monthly_rate > 0.007
                then previous.balance * previous.monthly_rate * m.interest_factor_2
            else previous.balance * previous.monthly_rate * m.interest_factor_3
        end as interest,
        case
            when previous.monthly_rate > 0.011
                then previous.balance * (1 + previous.monthly_rate * m.interest_factor) + a.apport
            when previous.monthly_rate > 0.007
                then previous.balance * (1 + previous.monthly_rate * m.interest_factor_2) + a.apport
            else previous.balance * (1 + previous.monthly_rate * m.interest_factor_3) + a.apport
        end as balance
    from monthly_balance as previous
    inner join simulation_months as m
        on previous.simulation_set = m.simulation_set
        and (date_trunc('month', previous.calendar_date) + interval '1 month')::date = m.calendar_date
    inner join apports as a
        on m.calendar_date = a.calendar_date
        and m.simulation_set = a.simulation_set
),

final as (
    select
        calendar_date,
        simulation_set,
        monthly_rate,
        adjusted_rate,
        apport,
        prev_balance,
        interest,
        balance
    from monthly_balance
)

select * from final
