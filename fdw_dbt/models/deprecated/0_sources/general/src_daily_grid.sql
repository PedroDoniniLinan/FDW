{{ config(schema='bronze', materialized='view') }}

with

    last_update as (select max(calendar_date) as last_update from {{ ref("src_balance_checks") }}) 

select *,
    'day'
    || case when calendar_date = (date_trunc('week', calendar_date) + interval '6 day')::date or calendar_date = last_update then 'week' else ''end
    || case when calendar_date = (date_trunc('month', calendar_date) + interval '1 month' - interval '1 day')::date or calendar_date = last_update then 'month' else '' end
    || case when calendar_date = (date_trunc('quarter', calendar_date) + interval '3 month' - interval '1 day')::date or calendar_date = last_update then 'quarter' else '' end
    || case when calendar_date = (date_trunc('year', calendar_date) + interval '1 year' - interval '1 day')::date or calendar_date = last_update then 'year' else '' end as is_end_of_period
from (
    select generate_series('2019-08-01'::date, (date_trunc('year', current_date) + interval '2 year'), interval '1 day')::date as calendar_date
) t
inner join last_update lu on (t.calendar_date <= lu.last_update)
order by calendar_date desc