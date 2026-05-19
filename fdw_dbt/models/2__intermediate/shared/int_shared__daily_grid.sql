{%- set start_dt = "'2019-08-01'::date" -%}
{%- set end_dt = "cast(date_trunc('year', current_date) + interval '1 year' as date)" -%}

{{ config(materialized='table') }}

with

    spine as (
        {{ date_spine("day", start_dt, end_dt) }}
    ),   

    last_update as (
        select max(calendar_date) as last_update 
        from {{ ref("stg_balances__last_update") }}
    ),

    final as (
        select
            s.date_day::date as calendar_date,
            'day'
            || case when s.date_day = (date_trunc('week', s.date_day) + interval '6 day')::date
                        or s.date_day = lu.last_update then 'week' else '' end
            || case when s.date_day = (date_trunc('month', s.date_day) + interval '1 month' - interval '1 day')::date
                        or s.date_day = lu.last_update then 'month' else '' end
            || case when s.date_day = (date_trunc('quarter', s.date_day) + interval '3 month' - interval '1 day')::date
                        or s.date_day = lu.last_update then 'quarter' else '' end
            || case when s.date_day = (date_trunc('year', s.date_day) + interval '1 year' - interval '1 day')::date
                        or s.date_day = lu.last_update then 'year' else '' end as is_end_of_period
        from spine s
            inner join last_update lu on (s.date_day <= lu.last_update)
    )

select * from final