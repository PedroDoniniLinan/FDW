{{ config(
    tags=['refactored', 'categories', 'main']
) }}

with

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
    from {{ ref('dim_expenses') }}
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
    from {{ ref('dim_income') }}
),

unioned_categories as (
    select * from dim_expenses
    union all
    select * from dim_income
    union all
    select * from {{ ref("int_transaction_categories__bonds") }}
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
)


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
