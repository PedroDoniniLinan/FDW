{% set start_date = '2018-09-23' %}
{% set end_date = '2025-09-24' %}

with

balance as (
    select *,
        lag(balance) over (order by calendar_date) as prev_balance,
        balance - lag(balance) over (order by calendar_date) as delta
    from (
    select
        calendar_date,
        sum(balance) as balance
    from {{ ref("balance_metrics") }}
    where currency = 'EUR'
        and time_grain = 'day'
        and calendar_date between '{{ start_date }}' and '{{ end_date }}'
    group by 1
    order by 1
    ) t
),

transactions as (
    select *
    from (
        select
            calendar_date,
            sum(amount) as amount
        from {{ ref("cashflow_metrics") }}
        where currency = 'EUR'
            and calendar_date between '{{ start_date }}' and '{{ end_date }}'
        group by 1
    )
)

{# select sum(diff) from ( #}
select 
    b.*,
    t.amount,
    round((b.delta - t.amount)::numeric, 1) as diff
from balance b
left join transactions t on b.calendar_date = t.calendar_date
{# where b.calendar_date = '{{ end_date }}' #}
where round((b.delta - t.amount)::numeric, 1) != 0
{# ) t  #}