with

    dim_expenses as (
        select
            md5(label)::uuid as category_id,
            label as category,
            'Expenses' as transaction_type,
            budget_level,
            level_1,
            level_2,
            level_3,
            frequency as source
        from {{ref('dim_expenses')}}
    ),

    dim_income as (
        select
            md5(label)::uuid as category_id,
            label as category,
            'Income' as transaction_type,
            source as budget_level,
            level_1,
            level_2,
            level_3,
            source
        from {{ref('dim_income')}}
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
                budget_level,
                level_1,
                level_2,
                level_3,
                source,
                row_number() over (partition by category, transaction_type order by level_1) as rn
            from unioned_categories
            where category is not null
        )
        where rn = 1
    )


select * from deduped_categories