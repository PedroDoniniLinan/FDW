{{ config(schema='gold', materialized='table') }}

{%- set time_grains = ['month', 'quarter', 'year'] -%}
{%- set aggregation_levels = [
    {'name': 'budget_level_3', 'source': 'daily_level_3_rows', 'dimensions': ['budget_level_1', 'budget_level_2', 'budget_level_3'], 'group_by_positions': [4, 5, 6, 7]},
    {'name': 'budget_level_1', 'source': 'daily_budget_1_rows', 'dimensions': ['budget_level_1'], 'group_by_positions': [5, 7]},
    {'name': 'budget_level_2', 'source': 'daily_budget_2_rows', 'dimensions': ['budget_level_1', 'budget_level_2'], 'group_by_positions': [5, 6, 7]},
    {'name': 'total', 'source': 'daily_total_rows', 'dimensions': [], 'group_by_positions': [7]}
] -%}
{%- set period_groups = [] -%}
{%- for grain in time_grains -%}
    {%- for level in aggregation_levels -%}
        {%- do period_groups.append({'grain': grain, 'level': level}) -%}
    {%- endfor -%}
{%- endfor -%}

with

daily_yield_inputs as (
    select
        calendar_date,
        currency,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        balance,
        interest
    from {{ ref('agg_blc__yield_daily') }}
),

daily_level_3_rows as (
    select
        calendar_date,
        currency,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        sum(balance) as balance,
        sum(interest) as interest
    from daily_yield_inputs
    group by 1, 2, 3, 4, 5
),

daily_budget_1_rows as (
    select
        calendar_date,
        budget_level_1,
        currency,
        sum(balance) as balance,
        sum(interest) as interest
    from daily_level_3_rows
    where budget_level_1 is not null
    group by 1, 2, 3
),

daily_budget_2_rows as (
    select
        calendar_date,
        budget_level_1,
        budget_level_2,
        currency,
        sum(balance) as balance,
        sum(interest) as interest
    from daily_level_3_rows
    where budget_level_2 is not null
    group by 1, 2, 3, 4
),

daily_total_rows as (
    select
        calendar_date,
        currency,
        sum(balance) as balance,
        sum(interest) as interest
    from daily_level_3_rows
    group by 1, 2
),

period_yield_rows as (
    {% for period_group in period_groups %}
    select
        (date_trunc('{{ period_group.grain }}', calendar_date)
            + interval '{{ "3 months" if period_group.grain == "quarter" else "1 " ~ period_group.grain }}'
            - interval '1 day')::date as calendar_date,
        '{{ period_group.grain }}' as time_grain,
        '{{ period_group.level.name }}' as aggregation_level,
        {% if 'budget_level_3' in period_group.level.dimensions %}budget_level_3{% else %}null::text{% endif %} as budget_level_3,
        {% if 'budget_level_1' in period_group.level.dimensions %}budget_level_1{% else %}null::text{% endif %} as budget_level_1,
        {% if 'budget_level_2' in period_group.level.dimensions %}budget_level_2{% else %}null::text{% endif %} as budget_level_2,
        currency,
        avg(case when balance > 0 then balance end) as avg_balance,
        sum(interest) as interest
    from {{ period_group.level.source }}
    group by
        1, 2, 3{% for position in period_group.level.group_by_positions %}, {{ position }}{% endfor %}
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
),

yield_metrics as (
    select
        calendar_date,
        time_grain,
        aggregation_level,
        budget_level_3,
        budget_level_1,
        budget_level_2,
        currency,
        avg_balance,
        interest,
        interest / nullif(avg_balance, 0) as yield
    from period_yield_rows
),

final as (
    select
        calendar_date,
        time_grain,
        aggregation_level,
        budget_level_3,
        budget_level_1,
        budget_level_2,
        currency,
        avg_balance,
        interest,
        yield
    from yield_metrics
)

select * from final
where aggregation_level = 'budget_level_2'
and budget_level_2 not in ('NFT games', 'Stablecoin')