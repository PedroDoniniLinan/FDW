{{ config(tags=['refactored', 'main', 'rated']) }}

with

balances as (
    select calendar_date, asset, currency, balance
    from {{ ref('fct_blc__balances_daily') }}
    where currency != 'Original'
),

transactions as (
    select calendar_date, asset, currency, transaction_type, category, amount
    from {{ ref('fct_trx__transactions_fiat_daily') }}
    where currency != 'Original'
),

categories as (
    select category, transaction_type, financial_level_2, budget_level_1, budget_level_2, budget_level_3
    from {{ ref('dim_trx__categories') }}
),

balance_aggregates as (
    select
        b.calendar_date,
        b.currency,
        c.budget_level_1,
        c.budget_level_2,
        c.budget_level_3,
        sum(b.balance) as balance
    from balances as b
    left join categories as c
        on b.asset = c.category
        and c.transaction_type = 'Income'
    group by 1, 2, 3, 4, 5
),

interest_aggregates as (
    select
        t.calendar_date,
        t.currency,
        c.budget_level_1,
        coalesce(c.budget_level_2, 'Unclassified') as budget_level_2,
        coalesce(c.budget_level_3, 'Unclassified') as budget_level_3,
        sum(t.amount) as interest
    from transactions as t
    left join categories as c
        on t.category = c.category
        and t.transaction_type = c.transaction_type
    where t.transaction_type = 'Income'
        and coalesce(c.financial_level_2, '') not in ('Work', 'Other sources')
        and coalesce(c.budget_level_2, '') <> 'Internal'
    group by 1, 2, 3, 4, 5
),

final as (
    select
        b.calendar_date,
        b.currency,
        b.budget_level_1,
        b.budget_level_2,
        b.budget_level_3,
        b.balance::double precision as balance,
        coalesce(i.interest, 0)::numeric as interest
    from balance_aggregates as b
    left join interest_aggregates as i
        on b.calendar_date = i.calendar_date
        and b.currency = i.currency
        and b.budget_level_1 = i.budget_level_1
        and b.budget_level_2 = i.budget_level_2
        and b.budget_level_3 = i.budget_level_3
)

select * from final
