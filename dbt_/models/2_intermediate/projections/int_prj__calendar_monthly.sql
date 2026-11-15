{{ config(
    tags=['refactored', 'projections']
) }}

with

monthly_dates as (
    select
        generate_series(
            '2023-12-01'::date,
            '2077-12-01'::date,
            interval '1 month'
        )::date as calendar_date
),

final as (
    select
        calendar_date,
        'day'
        || case
            when calendar_date = (date_trunc('quarter', calendar_date) + interval '2 month')::date
                then 'quarter'
            else ''
        end
        || case
            when calendar_date = (date_trunc('year', calendar_date) + interval '11 months')::date
                then 'year'
            else ''
        end as is_end_of_period
    from monthly_dates
)

select * from final
