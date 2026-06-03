{{ config(
    tags=['refactored', 'categories', 'main', 'mart', 'rated']
) }}

{%- set time_grain = ['month', 'quarter', 'year'] -%}

with

time_grain_agg as (
    {% for t in time_grain %}
    select
        {% if t in ['month', 'year'] %}
        (date_trunc('{{ t }}', calendar_date)
            + interval '1 {{ t }}' - interval '1 day')::date as calendar_date,{% endif %}
        {% if t in ['quarter'] %}
        (date_trunc('{{ t }}', calendar_date)
            + interval '3 month' - interval '1 day')::date as calendar_date,{% endif %}
        '{{ t }}' as time_grain,
        currency,
        sum(case when transaction_type = 'Income' then amount else 0 end) as income,
        sum(
            case
                when transaction_type = 'Income' and financial_level_2 in ('Work', 'Other sources') then amount else 0
            end
        ) as income_work,
        sum(
            case
                when
                    transaction_type = 'Income' and financial_level_2 not in ('Work', 'Other sources')
                    then amount else 0
            end
        ) as income_investments,
        sum(
            case
                when
                    transaction_type = 'Expenses'
                    and budget_level_1 not in ('Non-actionable', 'NFT')
                    and financial_level_1 = 'Essentials'
                    then -amount else 0
            end
        ) as expenses_essentials,
        sum(
            case
                when
                    transaction_type = 'Expenses'
                    and budget_level_1 not in ('Non-actionable', 'NFT')
                    and financial_level_1 != 'Essentials'
                    then -amount else 0
            end
        ) as expenses_non_essentials,
        sum(
            case
                when
                    transaction_type = 'Expenses' and budget_level_1 not in ('Non-actionable', 'NFT')
                    then -amount else 0
            end
        ) as expenses
    from {{ ref("fct_transactions_enriched") }}
    where transaction_type in ('Income', 'Expenses')
    group by
        1,
        time_grain,
        currency
    {% if not loop.last %}union all{% endif %}{% endfor %}
),

kpis as (
    select
        *,
        md5(calendar_date::text || time_grain || currency) as grain_id,
        (income_work - abs(expenses)) / nullif(income_work, 0) as savings_rate,
        (abs(expenses_essentials)) / nullif(income_work, 0) as essentials_burden_rate,
        (abs(expenses_non_essentials)) / nullif(income_work, 0) as non_essentials_burden_rate,
        income_investments / nullif(income_work, 0) as investment_to_work_ratio
    from time_grain_agg
)

select
    grain_id,
    time_grain,
    calendar_date,
    currency,
    income,
    income_work,
    income_investments,
    expenses,
    expenses_essentials,
    expenses_non_essentials,
    savings_rate,
    essentials_burden_rate,
    non_essentials_burden_rate,
    investment_to_work_ratio
from kpis
