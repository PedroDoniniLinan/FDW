{{ config(schema='gold', materialized='table') }}

with

    final as (
        select
            t.calendar_date,
            t.is_end_of_period,
            t.frequency,
            t.simulation_set,
            t.transaction_type,
            t.level_1,
            t.level_1 as level_2,
            t.level_1 as level_3,
            t.amount,
            case when t.transaction_type = 'Expenses' then -t.amount else t.amount end as abs_amount
        from {{ ref("int_transaction_projections_monthly") }} t
        union all
        (select
            calendar_date as calendar_date,
            is_end_of_period,
            'Yearly' as frequency,
            simulation_set,
            'Income' as transaction_type,
            'Investments' as level_1,
            i.level_2,
            b.level_3,
            sum(interest) as amount,
            sum(interest) as abs_amount
        from {{ source('silver', 'balance_projections') }} b
            left join {{ ref("income_categories") }} i on (b.level_3 = i.level_3)
        group by
            calendar_date,
            is_end_of_period,
            simulation_set,
            i.level_2,
            b.level_3)
    )

select * from final