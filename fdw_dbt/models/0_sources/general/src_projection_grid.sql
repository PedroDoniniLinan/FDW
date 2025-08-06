{{ config(schema='bronze', materialized='view') }}

with

    calendar_dates as (
        select *,
            'day'
            || case when calendar_date = (date_trunc('quarter', calendar_date) + interval '2 month')::date then 'quarter' else '' end
            || case when calendar_date = (date_trunc('year', calendar_date) + interval '11 months')::date then 'year' else '' end as is_end_of_period
        from (
            select generate_series('2023-12-01'::date, '2050-12-01'::date, interval '1 month')::date as calendar_date
        ) t
        order by calendar_date desc
    )
    
select *
from calendar_dates g