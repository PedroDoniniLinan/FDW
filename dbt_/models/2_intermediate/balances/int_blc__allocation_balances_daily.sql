{{ config(
    tags=['refactored', 'main', 'rated']
) }}

with

raw_balances as (
    select
        balance_id,
        account,
        asset,
        currency,
        calendar_date,
        balance
    from {{ ref("fct_blc__balances_daily") }}
),

raw_categories as (
    select
        category,
        transaction_type,
        category as category_key
    from {{ ref("dim_trx__categories") }}
),

raw_income as (
    select
        label,
        budget_level as level_1,
        budget_level_2 as level_2,
        budget_level_3 as level_3,
        label as category_key
    from {{ ref("dim_income") }}
),

raw_expenses as (
    select
        label,
        financial_level_1 as level_1,
        financial_level_2 as level_2,
        budget_level_3 as level_3,
        label as category_key
    from {{ ref("dim_expenses") }}
),

legacy_category_fields as (
    select
        c.category,
        c.transaction_type,
        case when c.transaction_type = 'Income' then i.level_1 else e.level_1 end as level_1,
        case when c.transaction_type = 'Income' then i.level_2 else e.level_2 end as level_2,
        coalesce(i.level_3, c.level_3) as level_3
    from raw_categories as c
    left join raw_income as i on c.category_key = i.category_key
    left join raw_expenses as e on c.category_key = e.category_key
),

classified_balances as (
    select
        b.balance_id,
        b.currency,
        b.calendar_date,
        c.level_1,
        c.level_2,
        c.level_3,
        c.level_1 as source,
        b.balance
    from raw_balances as b
    left join legacy_category_fields as c
        on b.asset = c.category
        and c.transaction_type = 'Income'
),

final as (
    select
        balance_id,
        currency,
        calendar_date,
        level_1,
        level_2,
        level_3,
        source,
        balance
    from classified_balances
)

select * from final
