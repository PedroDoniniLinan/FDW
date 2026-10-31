{{ config(
    tags=['refactored', 'categories', 'main']
) }}

with

raw_expense_categories as (
    select
        label,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3
    from {{ ref('dim_expenses') }}
),

raw_income_categories as (
    select
        label,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3
    from {{ ref('dim_income') }}
),

raw_bond_categories as (
    select
        category_id,
        category,
        transaction_type,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3
    from {{ ref("dim_trx__categories_bonds") }}
),

dim_expenses as (
    select
        md5(label || 'Expenses')::uuid as category_id,
        label as category,
        'Expenses' as transaction_type,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3
    from raw_expense_categories
),

dim_income as (
    select
        md5(label || 'Income')::uuid as category_id,
        label as category,
        'Income' as transaction_type,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3
    from raw_income_categories
),

unioned_categories as (
    select * from dim_expenses
    union all
    select * from dim_income
    union all
    select * from raw_bond_categories
),

deduped_categories as (
    select * from (
        select
            category_id,
            category,
            transaction_type,
            financial_level_1,
            financial_level_2,
            budget_level_1,
            budget_level_2,
            budget_level_3,
            row_number() over (partition by category, transaction_type order by budget_level_1) as rn
        from unioned_categories
        where category is not null
    ) as t
    where rn = 1
),

final as (
    select
        category_id,
        category,
        transaction_type,
        financial_level_1,
        financial_level_2,
        budget_level_1,
        budget_level_2,
        budget_level_3
    from deduped_categories
)


select * from final
