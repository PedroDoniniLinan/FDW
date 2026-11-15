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
    where c.budget_level_1 is not null
        and c.budget_level_2 is not null
        and c.budget_level_3 is not null
    group by 1, 2, 3, 4, 5
),

interest_aggregates as (
    select
        t.calendar_date,
        t.currency,
        c.budget_level_1,
        c.budget_level_2,
        c.budget_level_3,
        sum(t.amount) as interest
    from transactions as t
    left join categories as c
        on t.category = c.category
        and t.transaction_type = c.transaction_type
    where t.transaction_type = 'Income'
        and coalesce(c.financial_level_2, '') not in ('Work', 'Other sources')
        and coalesce(c.budget_level_2, '') <> 'Internal'
        and c.budget_level_1 is not null
        and c.budget_level_2 is not null
        and c.budget_level_3 is not null
    group by 1, 2, 3, 4, 5
),

daily_aggregates as (
    select
        coalesce(b.calendar_date, i.calendar_date) as calendar_date,
        coalesce(b.currency, i.currency) as currency,
        coalesce(b.budget_level_1, i.budget_level_1) as budget_level_1,
        coalesce(b.budget_level_2, i.budget_level_2) as budget_level_2,
        coalesce(b.budget_level_3, i.budget_level_3) as budget_level_3,
        coalesce(b.balance, 0)::double precision as balance,
        coalesce(i.interest, 0)::numeric as interest
    from balance_aggregates as b
    full outer join interest_aggregates as i
        on b.calendar_date = i.calendar_date
        and b.currency = i.currency
        and b.budget_level_1 = i.budget_level_1
        and b.budget_level_2 = i.budget_level_2
        and b.budget_level_3 = i.budget_level_3
),

keys as (
    select distinct currency, budget_level_1, budget_level_2, budget_level_3
    from daily_aggregates
),

calendar as (
    select generate_series(min(calendar_date), max(calendar_date), interval '1 day')::date as calendar_date
    from daily_aggregates
),

daily_spine as (
    select
        c.calendar_date,
        k.currency,
        k.budget_level_1,
        k.budget_level_2,
        k.budget_level_3,
        coalesce(a.balance, 0) as balance,
        coalesce(a.interest, 0) as interest
    from keys as k
    cross join calendar as c
    left join daily_aggregates as a
        on a.calendar_date = c.calendar_date
        and a.currency = k.currency
        and a.budget_level_1 = k.budget_level_1
        and a.budget_level_2 = k.budget_level_2
        and a.budget_level_3 = k.budget_level_3
),

daily_with_previous as (
    select
        calendar_date,
        currency,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        balance,
        interest,
        coalesce(lag(balance) over (
            partition by currency, budget_level_1, budget_level_2, budget_level_3
            order by calendar_date
        ), 0) as prev_balance
    from daily_spine
),

final as (
    select
        calendar_date,
        currency,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        balance,
        interest,
        prev_balance,
        balance - prev_balance - interest as flow
    from daily_with_previous
)

select * from final
