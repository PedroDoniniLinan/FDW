{{ config(materialized='view', tags=['refactored', 'projections']) }}

with

projections as (
    select
        calendar_date,
        simulation_set,
        transaction_type,
        budget_level_1,
        financial_level_2,
        amount
    from {{ ref('stg_projections__transactions') }}
),

projected_balances as (
    select
        calendar_date,
        simulation_set,
        interest
    from {{ ref('fct_prj__balances_monthly') }}
),

categories as (
    select
        transaction_type,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        max(budget_level_2) as budget_level_2
    from {{ ref('dim_trx__categories') }}
    where transaction_type = 'Expenses'
        or budget_level_1 = 'Other sources'
    group by 1, 2, 3, 4
    union all
    select
        transaction_type,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2
    from {{ ref('dim_trx__categories') }}
    where transaction_type = 'Income'
        and budget_level_1 != 'Other sources'
),

categorized_projections as (
    select
        date_trunc('month', p.calendar_date)::date as calendar_date,
        p.simulation_set,
        p.transaction_type,
        c.financial_level_1,
        p.financial_level_2,
        p.budget_level_1,
        c.budget_level_2,
        c.budget_level_2 as budget_level_3,
        p.amount
    from projections as p
    left join categories as c
        on p.transaction_type = c.transaction_type
        and p.financial_level_2 = c.financial_level_2
        and (
            p.budget_level_1 = c.budget_level_1 
                and (p.transaction_type = 'Expenses' or p.budget_level_1 = 'Other sources')
            or p.budget_level_1 = c.budget_level_2 and p.transaction_type = 'Income'
        )
),

monthly_projections as (
    select
        calendar_date,
        simulation_set,
        transaction_type,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        sum(amount) as amount
    from categorized_projections
    group by 1, 2, 3, 4, 5, 6, 7, 8
),

monthly_interest as (
    select
        date_trunc('month', calendar_date)::date as calendar_date,
        simulation_set,
        'Income'::text as transaction_type,
        'Invested'::text as financial_level_1,
        'Invested'::text as financial_level_2,
        'Invested'::text as budget_level_1,
        'Invested'::text as budget_level_2,
        'Invested'::text as budget_level_3,
        sum(interest) as amount
    from projected_balances
    group by 1, 2
),

unioned_transactions as (
    select * from monthly_projections
    union all
    select * from monthly_interest
),

final as (
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
    from unioned_transactions
)

select * from final
