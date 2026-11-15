{{ config(schema='gold', materialized='table') }}

with

projected_balances as (
    select
        calendar_date,
        simulation_set,
        balance
    from {{ ref('fct_prj__balances_monthly') }}
),

actual_balances as (
    select
        (date_trunc('month', calendar_date) + interval '1 month' - interval '1 day')::date as calendar_date,
        balance
    from {{ ref('fct_blc__balances_daily') }}
    where currency = 'EUR'
        and is_end_of_period ~* 'month'
        and account <> 'Nubank C'
),

balance_rows as (
    select
        calendar_date,
        'Projection ' || simulation_set::text as label,
        simulation_set,
        balance
    from projected_balances

    union all

    select
        calendar_date,
        'Actuals' as label,
        null::integer as simulation_set,
        sum(balance) as balance
    from actual_balances
    group by calendar_date
),

final as (
    select
        calendar_date,
        label,
        simulation_set,
        balance
    from balance_rows
)

select * from final
