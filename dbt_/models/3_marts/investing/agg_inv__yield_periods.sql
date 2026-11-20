{{
    config(
        schema='gold',
        materialized='incremental',
        incremental_strategy='microbatch',
        unique_key='period_key',
        event_time='calendar_date',
        begin='2019-01-01',
        batch_size='year',
        lookback=0
    )
}}
 
{#
    Microbatch by calendar year. Year is the coarsest grain, so every month, quarter and year period
    falls entirely inside one batch. Each run rebuilds the current year and the one before it (lookback=1).
    Older batches are not recomputed; restated history older than that needs a --full-refresh.
#}

{%- set time_grains = ['month', 'quarter', 'year'] -%}
{%- set min_avg_balance = {'BRL': 500, 'EUR': 100, 'USD': 100} -%}
{%- set aggregation_levels = [
    {'name': 'Budget 3', 'source': 'daily_level_3_rows', 'dimensions': ['budget_level_1', 'budget_level_2', 'budget_level_3'], 'group_by_positions': [4, 5, 6, 7]},
    {'name': 'Budget 1', 'source': 'daily_budget_1_rows', 'dimensions': ['budget_level_1'], 'group_by_positions': [5, 7]},
    {'name': 'Budget 2', 'source': 'daily_budget_2_rows', 'dimensions': ['budget_level_1', 'budget_level_2'], 'group_by_positions': [5, 6, 7]},
    {'name': 'Portfolio', 'source': 'daily_total_rows', 'dimensions': [], 'group_by_positions': [7]}
] -%}
{%- set period_groups = [] -%}
{%- for grain in time_grains -%}
    {%- for level in aggregation_levels -%}
        {%- do period_groups.append({'grain': grain, 'level': level}) -%}
    {%- endfor -%}
{%- endfor -%}

with

daily_level_3_rows as (
    select
        calendar_date,
        currency,
        budget_level_1,
        budget_level_2,
        budget_level_3,
        balance,
        interest,
        prev_balance,
        flow
    from {{ ref('agg_inv__yield_daily') }}
),

daily_budget_1_rows as (
    select
        calendar_date,
        budget_level_1,
        currency,
        sum(balance) as balance,
        sum(interest) as interest,
        sum(prev_balance) as prev_balance,
        sum(flow) as flow
    from daily_level_3_rows
    group by 1, 2, 3
),

daily_budget_2_rows as (
    select
        calendar_date,
        budget_level_1,
        budget_level_2,
        currency,
        sum(balance) as balance,
        sum(interest) as interest,
        sum(prev_balance) as prev_balance,
        sum(flow) as flow
    from daily_level_3_rows
    group by 1, 2, 3, 4
),

daily_total_rows as (
    select
        calendar_date,
        currency,
        sum(balance) as balance,
        sum(interest) as interest,
        sum(prev_balance) as prev_balance,
        sum(flow) as flow
    from daily_level_3_rows
    group by 1, 2
),

observed_dates as (
    select first_date, last_date
    from {{ ref('agg_inv__yield_date_bounds') }}
),

period_yield_rows as (
    {% for period_group in period_groups %}
    select
        period_end as calendar_date,
        '{{ period_group.grain }}' as time_grain,
        '{{ period_group.level.name }}' as aggregation_level,
        {% if period_group.level.dimensions %}{{ period_group.level.dimensions[-1] }}{% else %}null::text{% endif %} as budget_level_3,
        {% if 'budget_level_1' in period_group.level.dimensions %}budget_level_1{% else %}null::text{% endif %} as budget_level_1,
        {% if 'budget_level_2' in period_group.level.dimensions %}budget_level_2{% else %}null::text{% endif %} as budget_level_2,
        currency,
        max(observed_end - period_start + 1) as days_observed,
        sum(case when calendar_date = period_start then prev_balance end) as opening_balance,
        sum(flow * (observed_end - calendar_date))
            / max(observed_end - period_start + 1) as weighted_flows,
        sum(interest) as interest
    from (
        select
            s.*,
            (date_trunc('{{ period_group.grain }}', s.calendar_date)
                + interval '{{ "3 months" if period_group.grain == "quarter" else "1 " ~ period_group.grain }}'
                - interval '1 day')::date as period_end,
            least(
                (date_trunc('{{ period_group.grain }}', s.calendar_date)
                    + interval '{{ "3 months" if period_group.grain == "quarter" else "1 " ~ period_group.grain }}'
                    - interval '1 day')::date,
                o.last_date
            ) as observed_end,
            greatest(
                date_trunc('{{ period_group.grain }}', s.calendar_date)::date,
                o.first_date
            ) as period_start
        from {{ period_group.level.source }} as s
        cross join observed_dates as o
    ) as dated_rows
    group by
        1, 2, 3{% for position in period_group.level.group_by_positions %}, {{ position }}{% endfor %}
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
),

portfolio_member_rows as (
    {% for level in aggregation_levels if level.name != 'Portfolio' %}
    select
        calendar_date,
        time_grain,
        '{{ level.name }}' as aggregation_level,
        'Portfolio' as budget_level_3,
        {% if level.dimensions[-1] == 'budget_level_1' %}'Portfolio'{% else %}null::text{% endif %} as budget_level_1,
        {% if level.dimensions[-1] == 'budget_level_2' %}'Portfolio'{% else %}null::text{% endif %} as budget_level_2,
        currency,
        days_observed,
        opening_balance,
        weighted_flows,
        interest
    from period_yield_rows
    where aggregation_level = 'Portfolio'
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
),

yield_inputs as (
    select
        calendar_date,
        time_grain,
        aggregation_level,
        budget_level_3,
        budget_level_1,
        budget_level_2,
        currency,
        days_observed,
        opening_balance + weighted_flows as avg_balance,
        interest,
        case currency
            {% for currency, min_balance in min_avg_balance.items() %}
            when '{{ currency }}' then {{ min_balance }}
            {% endfor %}
        end as min_avg_balance
    from (
        select * from period_yield_rows where aggregation_level != 'Portfolio'
        union all
        select * from portfolio_member_rows
    ) as all_period_rows
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
        days_observed,
        avg_balance,
        interest,
        case
            when avg_balance >= min_avg_balance then interest / avg_balance
        end as yield
    from yield_inputs
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
        days_observed,
        avg_balance,
        interest,
        yield,
        case
            when yield > -1 then power(1 + yield, 365.0 / days_observed) - 1
        end as yield_annualized,
        -- unique_key for the microbatch merge; the budget columns are nullable, so they are coalesced
        md5(concat_ws('|', calendar_date, time_grain, aggregation_level,
            coalesce(budget_level_3, ''), coalesce(budget_level_1, ''), coalesce(budget_level_2, ''), currency)) as period_key
    from yield_metrics
)

select * from final
