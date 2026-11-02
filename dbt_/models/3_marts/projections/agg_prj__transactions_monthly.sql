{{ config(schema='gold', materialized='table') }}

with

projected_transactions as (
    select
        calendar_date,
        simulation_set,
        transaction_type,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        amount
    from {{ ref('fct_prj__transactions_monthly') }}
),

actual_transactions as (
    select
        date_trunc('month', calendar_date)::date as calendar_date,
        transaction_type,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        amount
    from {{ ref('fct_trx__transactions_enriched_daily') }}
    where transaction_type in ('Income', 'Expenses')
),

transaction_rows as (
    select
        calendar_date,
        'Projection ' || simulation_set::text as label,
        simulation_set,
        transaction_type,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        sum(amount) as amount
    from projected_transactions
    group by 1, 2, 3, 4, 5, 6, 7, 8, 9

    union all

    select
        calendar_date,
        'Actuals' as label,
        null::integer as simulation_set,
        transaction_type,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        sum(amount) as amount
    from actual_transactions
    group by 1, 4, 5, 6, 7, 8, 9
),

final as (
    select
        calendar_date,
        label,
        simulation_set,
        transaction_type,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        amount
    from transaction_rows
)

select * from final
